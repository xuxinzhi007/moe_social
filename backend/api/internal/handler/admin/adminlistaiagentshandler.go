package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListAiAgentsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListAiAgentsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListAiAgentsReq) (*types.AdminListAiAgentsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAiAgents(ctx, &moe.AdminListAiAgentsReq{
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
			Keyword:  req.Keyword,
			})
			if err != nil {
			return &types.AdminListAiAgentsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminAiAgentItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminAiAgentToTypes(item)
			}
			return &types.AdminListAiAgentsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListAiAgentsData{Items: items, Total: int(rpcResp.GetTotal())},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
