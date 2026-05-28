package vip

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		plan, err := svcCtx.VipGW.GetPlan(r.Context(), req.PlanId)
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetVipPlanResp{
				BaseResp: common.HandleVipGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP套餐成功"),
			Data:     common.VipPlanModelToTypes(plan),
		})
	}
}
