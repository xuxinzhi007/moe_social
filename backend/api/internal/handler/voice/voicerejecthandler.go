package voice

import (
	"errors"
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func VoiceRejectHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.VoiceRejectReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		session, ok := handlerutil.GetVoiceCall(req.CallId)
		if !ok {
			httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{Code: 0, Message: "success", Success: true})
			return
		}
		if session.ReceiverID != userID {
			httpx.ErrorCtx(r.Context(), w, errors.New("not allowed to reject this call"))
			return
		}

		handlerutil.PushJSONToChatUser(session.CallerID, map[string]interface{}{
			"type":    "call_rejected",
			"call_id": session.CallID,
		})
		handlerutil.RemoveVoiceCall(session.CallID)

		httpx.OkJsonCtx(r.Context(), w, &types.BaseResp{Code: 0, Message: "success", Success: true})
	}
}
