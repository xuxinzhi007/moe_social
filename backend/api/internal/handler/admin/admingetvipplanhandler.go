package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminGetVipPlanResp{BaseResp: *br})
			return
		}
		var req types.AdminGetVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetVipPlanReq) (resp *types.AdminGetVipPlanResp, err error) {
			plan, err := svcCtx.VipGW.GetPlan(r.Context(), req.PlanId)
			if err != nil {
			return &types.AdminGetVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			return &types.AdminGetVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.VipPlanModelToTypes(plan),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
