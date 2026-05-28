package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminAnalyticsOverviewHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (*types.AdminAnalyticsOverviewResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminAnalyticsOverview(r.Context(), &moe.AdminGetMemoryStatsReq{})
			if err != nil {
			return &types.AdminAnalyticsOverviewResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			return &types.AdminAnalyticsOverviewResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminAnalyticsOverviewToTypes(rpcResp),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
