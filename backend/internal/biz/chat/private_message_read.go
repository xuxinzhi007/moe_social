package chatbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListPrivateMessages 分页拉取两人私信历史（viewer 视角）。
func ListPrivateMessages(ctx context.Context, db *gorm.DB, in *moe.ListPrivateMessagesReq) (*moe.ListPrivateMessagesResp, error) {
	if db == nil {
		return nil, errors.New("db not ready")
	}
	viewer, err := strconv.ParseUint(strings.TrimSpace(in.GetViewerId()), 10, 32)
	if err != nil || viewer == 0 {
		return nil, errors.New("invalid viewer_id")
	}
	peer, err := strconv.ParseUint(strings.TrimSpace(in.GetPeerId()), 10, 32)
	if err != nil || peer == 0 {
		return nil, errors.New("invalid peer_id")
	}
	if viewer == peer {
		return nil, errors.New("invalid peer")
	}

	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}

	now := time.Now()
	q := db.WithContext(ctx).Model(&model.PrivateMessage{}).
		Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND expires_at > ?",
			uint(viewer), uint(peer), uint(peer), uint(viewer), now)

	if bid := strings.TrimSpace(in.GetBeforeId()); bid != "" {
		beforeUint, err := strconv.ParseUint(bid, 10, 32)
		if err != nil {
			return nil, errors.New("invalid before_id")
		}
		q = q.Where("id < ?", uint(beforeUint))
	}

	var rows []model.PrivateMessage
	if err := q.Order("id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, errors.New("query failed")
	}

	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}

	idSet := make(map[uint]struct{})
	for _, r := range rows {
		idSet[r.SenderID] = struct{}{}
		idSet[r.ReceiverID] = struct{}{}
	}
	ids := make([]uint, 0, len(idSet))
	for id := range idSet {
		ids = append(ids, id)
	}
	moeBy := loadMoeNoByUserID(db.WithContext(ctx), ids...)

	out := make([]*moe.PrivateMessage, 0, len(rows))
	for i := len(rows) - 1; i >= 0; i-- {
		out = append(out, privateMessageModelToProto(&rows[i], moeBy))
	}

	return &moe.ListPrivateMessagesResp{Messages: out, HasMore: hasMore}, nil
}

// ListPrivateConversations 列出 viewer 的私信会话摘要。
func ListPrivateConversations(ctx context.Context, db *gorm.DB, in *moe.ListPrivateConversationsReq) (*moe.ListPrivateConversationsResp, error) {
	if db == nil {
		return nil, errors.New("db not ready")
	}
	viewerID, err := strconv.ParseUint(strings.TrimSpace(in.GetViewerId()), 10, 32)
	if err != nil || viewerID == 0 {
		return nil, errors.New("invalid viewer_id")
	}

	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 30
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.GetOffset())
	if offset < 0 {
		offset = 0
	}

	now := time.Now()
	dbCtx := db.WithContext(ctx)

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
	if err := dbCtx.Raw(countSQL, uint(viewerID), uint(viewerID), uint(viewerID), now).Scan(&totalRow).Error; err != nil {
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
	if err := dbCtx.Raw(listSQL, uint(viewerID), uint(viewerID), uint(viewerID), now, limit, offset).Scan(&rows).Error; err != nil {
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
		if err := dbCtx.Where("id IN ?", lastIDs).Find(&msgs).Error; err != nil {
			return nil, err
		}
		for _, m := range msgs {
			msgByID[m.ID] = m
		}
	}

	userByID := map[uint]model.User{}
	if len(peerIDs) > 0 {
		var users []model.User
		if err := dbCtx.Select("id", "username", "avatar", "moe_no").Where("id IN ?", peerIDs).Find(&users).Error; err != nil {
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
	if err := dbCtx.Model(&model.Notification{}).
		Select("sender_id AS peer_id, COUNT(1) AS unread_count").
		Where("user_id = ? AND type = ? AND is_read = ?", uint(viewerID), 6, false).
		Group("sender_id").
		Scan(&unreadRows).Error; err != nil {
		return nil, err
	}
	for _, row := range unreadRows {
		unreadByPeer[row.PeerID] = int32(row.UnreadCount)
	}

	moeBy := loadMoeNoByUserID(dbCtx, append(peerIDs, uint(viewerID))...)
	out := make([]*moe.PrivateConversation, 0, len(rows))
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
		out = append(out, &moe.PrivateConversation{
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
	return &moe.ListPrivateConversationsResp{
		Conversations: out,
		Total:         int32(totalRow.Total),
		Limit:         int32(limit),
		Offset:        int32(offset),
		HasMore:       hasMore,
	}, nil
}
