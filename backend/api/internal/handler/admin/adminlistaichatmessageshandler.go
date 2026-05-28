//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListAiChatMessagesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminListAiChatMessagesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListAiChatMessagesReq) (*types.AdminListAiChatMessagesResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAiChatMessages(r.Context(), &moe.AdminListAiChatMessagesReq{
			Page:      int32(req.Page),
			PageSize:  int32(req.PageSize),
			UserId:    req.UserId,
			SessionId: req.SessionId,
			Role:      req.Role,
			Keyword:   req.Keyword,
			From:      req.From,
			To:        req.To,
			})
			if err != nil {
			return &types.AdminListAiChatMessagesResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminAiChatMessageItem, 0, len(rpcResp.GetItems()))
			for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAiChatMessageToTypes(row))
			}
			return &types.AdminListAiChatMessagesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListAiChatMessagesData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
			},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
