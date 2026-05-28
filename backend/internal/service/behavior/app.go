// Package behaviorapp 用户行为埋点应用服务（Sprint S4）。
package behaviorapp

import (
	"context"

	behaviorbiz "backend/internal/biz/behavior"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AppService 行为域应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// TrackEvents 批量上报行为事件。
func (s *AppService) TrackEvents(ctx context.Context, in *moe.TrackUserBehaviorEventsReq) (*moe.TrackUserBehaviorEventsResp, error) {
	events := in.GetEvents()
	if len(events) == 0 {
		return &moe.TrackUserBehaviorEventsResp{Accepted: 0}, nil
	}
	userID := in.GetUserId()
	if userID == 0 {
		return nil, behaviorbiz.ErrInvalidUser
	}
	inputs := make([]behaviorbiz.EventInput, 0, len(events))
	for _, ev := range events {
		inputs = append(inputs, behaviorbiz.EventInput{
			Event:      ev.GetEvent(),
			Screen:     ev.GetScreen(),
			ParamsJSON: ev.GetParamsJson(),
			DurationMs: ev.GetDurationMs(),
			SessionID:  ev.GetSessionId(),
			ClientTsMs: ev.GetClientTsMs(),
		})
	}
	accepted, err := behaviorbiz.TrackEvents(ctx, s.db, uint(userID), inputs)
	if err != nil {
		return nil, err
	}
	return &moe.TrackUserBehaviorEventsResp{Accepted: accepted}, nil
}
