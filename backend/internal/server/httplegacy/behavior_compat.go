package httplegacy

import (
	"net/http"
	"strconv"

	behaviorv1 "backend/api/behavior/v1"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	behaviorapp "backend/internal/service/behavior"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeBehaviorCompatRoutes 行为埋点域 Kratos HTTP。
const PilotNativeBehaviorCompatRoutes = 0

// RegisterBehaviorCompat D2：已迁入 RegisterBehaviorAppHTTPServer。
func RegisterBehaviorCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	_ = srv
	_ = svcCtx
}

func trackBehavior(app *behaviorapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.TrackUserBehaviorEventsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		protoReq, err := behaviorHTTPToProto(&req)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.TrackEvents(ctx, protoReq)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.TrackUserBehaviorEventsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     types.TrackUserBehaviorEventsData{Accepted: int(rpcResp.GetAccepted())},
		})
	}
}

func behaviorHTTPToProto(req *types.TrackUserBehaviorEventsReq) (*behaviorv1.TrackUserBehaviorEventsRequest, error) {
	userID, err := strconv.ParseUint(req.UserId, 10, 64)
	if err != nil || userID == 0 {
		return nil, errInvalidUserID
	}
	events := make([]*behaviorv1.UserBehaviorEventItem, 0, len(req.Events))
	for _, item := range req.Events {
		params := item.Params
		if params == nil {
			params = map[string]string{}
		}
		events = append(events, &behaviorv1.UserBehaviorEventItem{
			Event:      item.Event,
			Screen:     item.Screen,
			Params:     params,
			DurationMs: item.DurationMs,
			SessionId:  item.SessionId,
			ClientTs:   item.ClientTs,
		})
	}
	return &behaviorv1.TrackUserBehaviorEventsRequest{
		UserId: userID,
		Events: events,
	}, nil
}

// errInvalidUserID 与历史 handler 文案一致。
var errInvalidUserID = &behaviorInvalidUserID{}

type behaviorInvalidUserID struct{}

func (e *behaviorInvalidUserID) Error() string { return "invalid user_id" }
