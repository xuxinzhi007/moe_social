package moehttp

import (
	"encoding/json"
	"net/http"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	behaviorapp "backend/internal/service/behavior"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeBehaviorCompatRoutes 行为埋点域 Kratos HTTP。
const PilotNativeBehaviorCompatRoutes = 1

// RegisterBehaviorCompat POST /api/user/:user_id/behavior/events
func RegisterBehaviorCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.BehaviorApp == nil {
		return
	}
	app := svcCtx.BehaviorApp
	r := srv.Route("/")
	r.POST("/api/user/:user_id/behavior/events", trackBehavior(app))
}

func trackBehavior(app *behaviorapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.TrackUserBehaviorEventsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		userID, err := strconv.ParseUint(req.UserId, 10, 64)
		if err != nil || userID == 0 {
			return ctx.JSON(http.StatusOK, types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: "invalid user_id", Success: false},
			})
		}
		events := make([]*moe.UserBehaviorEventInput, 0, len(req.Events))
		for _, item := range req.Events {
			paramsJSON := ""
			if len(item.Params) > 0 {
				if b, marshalErr := json.Marshal(item.Params); marshalErr == nil {
					paramsJSON = string(b)
				}
			}
			events = append(events, &moe.UserBehaviorEventInput{
				Event:      item.Event,
				Screen:     item.Screen,
				ParamsJson: paramsJSON,
				DurationMs: item.DurationMs,
				SessionId:  item.SessionId,
				ClientTsMs: item.ClientTs,
			})
		}
		rpcResp, err := app.TrackEvents(ctx, &moe.TrackUserBehaviorEventsReq{
			UserId: userID,
			Events: events,
		})
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
