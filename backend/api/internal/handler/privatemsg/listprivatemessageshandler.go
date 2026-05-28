//go:build hybrid

// Code scaffolded by goctl. Safe to edit.

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

func ListPrivateMessagesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ListPrivateMessagesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		viewerID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.ChatGW.ListPrivateMessages(r.Context(), &moe.ListPrivateMessagesReq{
			ViewerId: viewerID,
			PeerId:   req.PeerUserId,
			BeforeId: req.BeforeId,
			Limit:    int32(req.Limit),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListPrivateMessagesResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		items := make([]types.PrivateMessageItem, 0, len(rpcResp.Messages))
		for _, m := range rpcResp.Messages {
			if m == nil {
				continue
			}
			items = append(items, handlerutil.PrivateMessageFromProto(m))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ListPrivateMessagesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			HasMore:  rpcResp.HasMore,
		})
	}
}
