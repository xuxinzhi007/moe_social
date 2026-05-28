package behavior

import (
	"encoding/json"
	"net/http"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func TrackUserBehaviorEventsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.TrackUserBehaviorEventsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "missing or invalid authorization header", http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		userID, err := utils.GetUserIDFromToken(tokenString)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		uid := uint64(userID)
		if uid == 0 {
			httpx.OkJsonCtx(r.Context(), w, &types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: "invalid user_id", Success: false},
			})
			return
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
				Event: item.Event, Screen: item.Screen, ParamsJson: paramsJSON,
				DurationMs: item.DurationMs, SessionId: item.SessionId, ClientTsMs: item.ClientTs,
			})
		}

		rpcResp, err := svcCtx.BehaviorGW.TrackUserBehaviorEvents(r.Context(), &moe.TrackUserBehaviorEventsReq{
			UserId: uid, Events: events,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.TrackUserBehaviorEventsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.TrackUserBehaviorEventsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     types.TrackUserBehaviorEventsData{Accepted: int(rpcResp.GetAccepted())},
		})
	}
}
