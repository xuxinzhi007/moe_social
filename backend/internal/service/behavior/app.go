// Package behaviorapp 用户行为埋点应用服务（Sprint S4）。
package behaviorapp

import (
	"context"
	"encoding/json"

	behaviorv1 "backend/api/behavior/v1"
	behaviorbiz "backend/internal/biz/behavior"
	behaviordata "backend/internal/data/behavior"

	"gorm.io/gorm"
)

// AppService 行为域应用层。
type AppService struct {
	store behaviorbiz.BehaviorStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: behaviordata.NewStore(db)}
}

// TrackEvents 批量上报行为事件。
func (s *AppService) TrackEvents(ctx context.Context, in *behaviorv1.TrackUserBehaviorEventsRequest) (*behaviorv1.TrackUserBehaviorEventsReply, error) {
	events := in.GetEvents()
	if len(events) == 0 {
		return &behaviorv1.TrackUserBehaviorEventsReply{Accepted: 0}, nil
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
			ParamsJSON: behaviorEventParamsJSON(ev),
			DurationMs: ev.GetDurationMs(),
			SessionID:  ev.GetSessionId(),
			ClientTsMs: ev.GetClientTs(),
		})
	}
	accepted, err := behaviorbiz.TrackEvents(ctx, s.store, uint(userID), inputs)
	if err != nil {
		return nil, err
	}
	return &behaviorv1.TrackUserBehaviorEventsReply{Accepted: int32(accepted)}, nil
}

func behaviorEventParamsJSON(ev *behaviorv1.UserBehaviorEventItem) string {
	if ev == nil {
		return ""
	}
	if pj := ev.GetParamsJson(); pj != "" {
		return pj
	}
	m := ev.GetParams()
	if len(m) == 0 {
		return ""
	}
	b, err := json.Marshal(m)
	if err != nil {
		return ""
	}
	return string(b)
}
