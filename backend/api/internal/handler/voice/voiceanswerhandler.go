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

func VoiceAnswerHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.VoiceAnswerReq
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
			httpx.ErrorCtx(r.Context(), w, errors.New("call not found or expired"))
			return
		}
		if session.ReceiverID != userID {
			httpx.ErrorCtx(r.Context(), w, errors.New("not allowed to answer this call"))
			return
		}

		handlerutil.PushJSONToChatUser(session.CallerID, map[string]interface{}{
			"type":         "call_answered",
			"call_id":      session.CallID,
			"channel_name": session.ChannelName,
		})

		httpx.OkJsonCtx(r.Context(), w, &types.VoiceAnswerResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: "success",
				Success: true,
			},
			Data: types.VoiceAnswerData{
				ChannelName: session.ChannelName,
			},
		})
	}
}
