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

type ListPrivateMessagesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListPrivateMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateMessagesLogic {
	return &ListPrivateMessagesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListPrivateMessagesLogic) ListPrivateMessages(in *super.ListPrivateMessagesReq) (*super.ListPrivateMessagesResp, error) {
	viewer, err := strconv.ParseUint(strings.TrimSpace(in.ViewerId), 10, 32)
	if err != nil || viewer == 0 {
		return nil, errors.New("invalid viewer_id")
	}
	peer, err := strconv.ParseUint(strings.TrimSpace(in.PeerId), 10, 32)
	if err != nil || peer == 0 {
		return nil, errors.New("invalid peer_id")
	}
	if viewer == peer {
		return nil, errors.New("invalid peer")
	}

	limit := int(in.Limit)
	if limit <= 0 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}

	now := time.Now()
	q := l.svcCtx.DB.Model(&model.PrivateMessage{}).
		Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND expires_at > ?",
			uint(viewer), uint(peer), uint(peer), uint(viewer), now)

	if bid := strings.TrimSpace(in.BeforeId); bid != "" {
		beforeUint, err := strconv.ParseUint(bid, 10, 32)
		if err != nil {
			return nil, errors.New("invalid before_id")
		}
		q = q.Where("id < ?", uint(beforeUint))
	}

	var rows []model.PrivateMessage
	if err := q.Order("id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		l.Errorf("list private_message: %v", err)
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
	moeBy := loadMoeNoByUserID(l.svcCtx.DB, ids...)

	out := make([]*super.PrivateMessage, 0, len(rows))
	for i := len(rows) - 1; i >= 0; i-- {
		out = append(out, privateMessageModelToProto(&rows[i], moeBy))
	}

	return &super.ListPrivateMessagesResp{Messages: out, HasMore: hasMore}, nil
}
