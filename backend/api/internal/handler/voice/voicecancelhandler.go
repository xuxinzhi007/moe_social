//go:build hybrid

package voice

import (
	"errors"
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func VoiceCancelHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.VoiceCancelReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		callerID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		if req.CallId != "" {
			if session, ok := handlerutil.GetVoiceCall(req.CallId); ok {
				if session.CallerID != callerID {
					httpx.ErrorCtx(r.Context(), w, errors.New("not allowed to cancel this call"))
					return
				}
				handlerutil.PushJSONToChatUser(session.ReceiverID, map[string]interface{}{
					"type":    "call_cancelled",
					"call_id": session.CallID,
				})
				handlerutil.RemoveVoiceCall(session.CallID)
			}
		}

		httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{Code: 0, Message: "success", Success: true})
	}
}
