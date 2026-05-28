package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetGrowthStatsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (*types.AdminGetGrowthStatsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminGetGrowthStats(ctx, &moe.AdminGetGrowthStatsReq{})
			if err != nil {
			return &types.AdminGetGrowthStatsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminGetGrowthStatsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminGrowthStatsToTypes(rpcResp.GetStats()),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
