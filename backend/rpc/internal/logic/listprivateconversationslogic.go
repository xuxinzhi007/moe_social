package logic

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPrivateConversationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListPrivateConversationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateConversationsLogic {
	return &ListPrivateConversationsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListPrivateConversationsLogic) ListPrivateConversations(in *super.ListPrivateConversationsReq) (*super.ListPrivateConversationsResp, error) {
	viewerID, err := strconv.ParseUint(strings.TrimSpace(in.ViewerId), 10, 32)
	if err != nil || viewerID == 0 {
		return nil, errors.New("invalid viewer_id")
	}

	limit := int(in.Limit)
	if limit <= 0 {
		limit = 30
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.Offset)
	if offset < 0 {
		offset = 0
	}

	now := time.Now()

	type countRow struct {
		Total int64 `gorm:"column:total"`
	}
	var totalRow countRow
	countSQL := `
SELECT COUNT(1) AS total
FROM (
  SELECT CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS peer_id
  FROM private_messages
  WHERE (sender_id = ? OR receiver_id = ?) AND expires_at > ?
  GROUP BY peer_id
) t`
	if err := l.svcCtx.DB.Raw(countSQL, uint(viewerID), uint(viewerID), uint(viewerID), now).Scan(&totalRow).Error; err != nil {
		l.Errorf("count private conversations failed: %v", err)
		return nil, err
	}

	type convRow struct {
		PeerID uint `gorm:"column:peer_id"`
		LastID uint `gorm:"column:last_id"`
	}
	var rows []convRow
	listSQL := `
SELECT
  CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS peer_id,
  MAX(id) AS last_id
FROM private_messages
WHERE (sender_id = ? OR receiver_id = ?) AND expires_at > ?
GROUP BY peer_id
ORDER BY last_id DESC
LIMIT ? OFFSET ?`
	if err := l.svcCtx.DB.Raw(listSQL, uint(viewerID), uint(viewerID), uint(viewerID), now, limit, offset).Scan(&rows).Error; err != nil {
		l.Errorf("list private conversations failed: %v", err)
		return nil, err
	}

	lastIDs := make([]uint, 0, len(rows))
	peerIDs := make([]uint, 0, len(rows))
	for _, row := range rows {
		if row.PeerID == 0 || row.LastID == 0 {
			continue
		}
		peerIDs = append(peerIDs, row.PeerID)
		lastIDs = append(lastIDs, row.LastID)
	}

	msgByID := map[uint]model.PrivateMessage{}
	if len(lastIDs) > 0 {
		var msgs []model.PrivateMessage
		if err := l.svcCtx.DB.Where("id IN ?", lastIDs).Find(&msgs).Error; err != nil {
			l.Errorf("query last private messages failed: %v", err)
			return nil, err
		}
		for _, m := range msgs {
			msgByID[m.ID] = m
		}
	}

	userByID := map[uint]model.User{}
	if len(peerIDs) > 0 {
		var users []model.User
		if err := l.svcCtx.DB.Select("id", "username", "avatar", "moe_no").Where("id IN ?", peerIDs).Find(&users).Error; err != nil {
			l.Errorf("query conversation peers failed: %v", err)
			return nil, err
		}
		for _, u := range users {
			userByID[u.ID] = u
		}
	}

	type unreadRow struct {
		PeerID      uint  `gorm:"column:peer_id"`
		UnreadCount int64 `gorm:"column:unread_count"`
	}
	unreadByPeer := map[uint]int32{}
	var unreadRows []unreadRow
	if err := l.svcCtx.DB.Model(&model.Notification{}).
		Select("sender_id AS peer_id, COUNT(1) AS unread_count").
		Where("user_id = ? AND type = ? AND is_read = ?", uint(viewerID), 6, false).
		Group("sender_id").
		Scan(&unreadRows).Error; err != nil {
		l.Errorf("query private unread counts failed: %v", err)
		return nil, err
	}
	for _, row := range unreadRows {
		unreadByPeer[row.PeerID] = int32(row.UnreadCount)
	}

	moeBy := loadMoeNoByUserID(l.svcCtx.DB, append(peerIDs, uint(viewerID))...)
	out := make([]*super.PrivateConversation, 0, len(rows))
	for _, row := range rows {
		msg, ok := msgByID[row.LastID]
		if !ok {
			continue
		}
		peer := userByID[row.PeerID]
		peerName := strings.TrimSpace(peer.Username)
		if peerName == "" {
			peerName = "用户"
		}
		lastMsg := privateMessageModelToProto(&msg, moeBy)
		if strings.TrimSpace(lastMsg.GetBody()) == "" && len(lastMsg.GetImagePaths()) > 0 {
			lastMsg.Body = "[IMG]"
		}
		out = append(out, &super.PrivateConversation{
			PeerId:            strconv.FormatUint(uint64(row.PeerID), 10),
			PeerName:          peerName,
			PeerAvatar:        strings.TrimSpace(peer.Avatar),
			PeerMoeNo:         strings.TrimSpace(peer.MoeNo),
			PeerDisplayUserId: strings.TrimSpace(peer.MoeNo),
			LastMessage:       lastMsg,
			UnreadCount:       unreadByPeer[row.PeerID],
		})
	}

	hasMore := int64(offset+len(out)) < totalRow.Total
	return &super.ListPrivateConversationsResp{
		Conversations: out,
		Total:         int32(totalRow.Total),
		Limit:         int32(limit),
		Offset:        int32(offset),
		HasMore:       hasMore,
	}, nil
}
