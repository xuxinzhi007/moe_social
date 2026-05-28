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

func ListPrivateConversationsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ListPrivateConversationsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		viewerID, err := handlerutil.CtxUserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.ChatGW.ListPrivateConversations(r.Context(), &moe.ListPrivateConversationsReq{
			ViewerId: viewerID,
			Limit:    int32(req.Limit),
			Offset:   int32(req.Offset),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListPrivateConversationsResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		items := make([]types.PrivateConversationItem, 0, len(rpcResp.Conversations))
		for _, c := range rpcResp.Conversations {
			if c == nil {
				continue
			}
			items = append(items, handlerutil.PrivateConversationFromProto(c))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ListPrivateConversationsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			Total:    int(rpcResp.GetTotal()),
			Limit:    int(rpcResp.GetLimit()),
			Offset:   int(rpcResp.GetOffset()),
			HasMore:  rpcResp.GetHasMore(),
		})
	}
}
