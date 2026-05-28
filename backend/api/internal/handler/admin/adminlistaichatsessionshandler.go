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

func AdminListAiChatSessionsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminListAiChatSessionsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListAiChatSessionsReq) (*types.AdminListAiChatSessionsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAiChatSessions(r.Context(), &moe.AdminListAiChatSessionsReq{
			Page:      int32(req.Page),
			PageSize:  int32(req.PageSize),
			UserId:    req.UserId,
			SessionId: req.SessionId,
			From:      req.From,
			To:        req.To,
			})
			if err != nil {
			return &types.AdminListAiChatSessionsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminAiChatSessionItem, 0, len(rpcResp.GetItems()))
			for _, row := range rpcResp.GetItems() {
			items = append(items, common.RpcAdminAiChatSessionToTypes(row))
			}
			return &types.AdminListAiChatSessionsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListAiChatSessionsData{
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
