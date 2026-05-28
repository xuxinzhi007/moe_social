package logic

import (
	"context"
	"errors"

	behaviorbiz "backend/internal/biz/behavior"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type TrackUserBehaviorEventsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewTrackUserBehaviorEventsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *TrackUserBehaviorEventsLogic {
	return &TrackUserBehaviorEventsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *TrackUserBehaviorEventsLogic) TrackUserBehaviorEvents(in *moe.TrackUserBehaviorEventsReq) (*moe.TrackUserBehaviorEventsResp, error) {
	events := in.GetEvents()
	if len(events) == 0 {
		return &moe.TrackUserBehaviorEventsResp{Accepted: 0}, nil
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

	accepted, err := behaviorbiz.TrackEvents(l.ctx, l.svcCtx.BehaviorStore(), uint(in.GetUserId()), inputs)
	if err != nil {
		switch {
		case errors.Is(err, behaviorbiz.ErrInvalidUser):
			return nil, errors.New("invalid user_id")
		case errors.Is(err, behaviorbiz.ErrBatchTooLarge):
			return nil, errors.New("events batch too large")
		default:
			return nil, err
		}
	}

	return &moe.TrackUserBehaviorEventsResp{Accepted: accepted}, nil
}
