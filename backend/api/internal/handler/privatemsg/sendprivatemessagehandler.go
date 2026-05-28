//go:build hybrid

// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package privatemsg

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendPrivateMessageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendPrivateMessageReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		senderID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.ChatGW.SendPrivateMessage(r.Context(), &moe.SendPrivateMessageReq{
			SenderId:   senderID,
			ReceiverId: req.ReceiverId,
			Body:       req.Body,
			ImagePaths: req.ImagePaths,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendPrivateMessageResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}
		if rpcResp.Message == nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendPrivateMessageResp{
				BaseResp: common.HandleRPCError(nil, "发送失败"),
			})
			return
		}

		senderName, senderAvatar := handlerutil.ResolvePrivateMessageSenderProfile(
			r.Context(), svcCtx, senderID, rpcResp.Message, "",
		)
		handlerutil.DeliverPrivateMessageRealTime(r.Context(), svcCtx, senderID, req.ReceiverId, req.Body, senderName, senderAvatar, rpcResp.Message)

		httpx.OkJsonCtx(r.Context(), w, &types.SendPrivateMessageResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     handlerutil.PrivateMessageFromProto(rpcResp.Message),
		})
	}
}
