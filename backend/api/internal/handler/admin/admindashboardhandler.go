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

func AdminDashboardHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminDashboardResp{BaseResp: *br})
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (resp *types.AdminDashboardResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminDashboard(r.Context(), &moe.AdminDashboardReq{})
			if err != nil {
			return &types.AdminDashboardResp{
			BaseResp: common.HandleRPCError(err, ""),
			}, nil
			}

			return &types.AdminDashboardResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminDashboardData{
			LandingFeedbackTotal: int(rpcResp.LandingFeedbackTotal),
			UserTotal:            int(rpcResp.UserTotal),
			ServerTime:           rpcResp.ServerTime,
			FeishuEnabled:        rpcResp.FeishuEnabled,
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
