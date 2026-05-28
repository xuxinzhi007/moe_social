//go:build hybrid

package voice

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/google/uuid"
	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func VoiceCallHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.VoiceCallReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		callerID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		receiverID := strings.TrimSpace(req.ReceiverId)
		if receiverID == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("receiver_id required"))
			return
		}
		if receiverID == callerID {
			httpx.ErrorCtx(r.Context(), w, errors.New("cannot call yourself"))
			return
		}

		callID := uuid.New().String()
		channelName := fmt.Sprintf("call_%s", callID)

		callerName, callerAvatar := handlerutil.ResolveVoiceUserDisplay(r.Context(), svcCtx, callerID)

		session := handlerutil.NewVoiceCallSession(callID, channelName, callerID, receiverID, callerName, callerAvatar)
		handlerutil.PutVoiceCall(session)

		payload := map[string]interface{}{
			"type":          "incoming_call",
			"call_id":       callID,
			"channel_name":  channelName,
			"caller_id":     callerID,
			"caller_name":   callerName,
			"caller_avatar": callerAvatar,
		}
		if !handlerutil.PushJSONToChatUser(receiverID, payload) {
			logx.WithContext(r.Context()).Infof("voice call: receiver %s not on chat ws, incoming_call not delivered live", receiverID)
		}

		httpx.OkJsonCtx(r.Context(), w, &types.VoiceCallResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: "success",
				Success: true,
			},
			Data: types.VoiceCallData{
				CallId:      callID,
				ChannelName: channelName,
			},
		})
	}
}
