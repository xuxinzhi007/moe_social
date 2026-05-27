package behavior

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type TrackUserBehaviorEventsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewTrackUserBehaviorEventsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *TrackUserBehaviorEventsLogic {
	return &TrackUserBehaviorEventsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *TrackUserBehaviorEventsLogic) TrackUserBehaviorEvents(req *types.TrackUserBehaviorEventsReq) (*types.TrackUserBehaviorEventsResp, error) {
	userID, err := strconv.ParseUint(req.UserId, 10, 64)
	if err != nil || userID == 0 {
		return &types.TrackUserBehaviorEventsResp{
			BaseResp: types.BaseResp{Code: -1, Message: "invalid user_id", Success: false},
		}, nil
	}

	events := make([]*super.UserBehaviorEventInput, 0, len(req.Events))
	for _, item := range req.Events {
		paramsJSON := ""
		if len(item.Params) > 0 {
			if b, marshalErr := json.Marshal(item.Params); marshalErr == nil {
				paramsJSON = string(b)
			}
		}
		events = append(events, &super.UserBehaviorEventInput{
			Event:      item.Event,
			Screen:     item.Screen,
			ParamsJson: paramsJSON,
			DurationMs: item.DurationMs,
			SessionId:  item.SessionId,
			ClientTsMs: item.ClientTs,
		})
	}

	rpcResp, err := l.svcCtx.BehaviorGW.TrackUserBehaviorEvents(l.ctx, &super.TrackUserBehaviorEventsReq{
		UserId: userID,
		Events: events,
	})
	if err != nil {
		return &types.TrackUserBehaviorEventsResp{
			BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
		}, nil
	}

	return &types.TrackUserBehaviorEventsResp{
		BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
		Data: types.TrackUserBehaviorEventsData{
			Accepted: int(rpcResp.GetAccepted()),
		},
	}, nil
}
