package vip

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetVipPlansHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rows, err := svcCtx.VipGW.ListAllPlans(r.Context())
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetVipPlansResp{
				BaseResp: common.HandleVipGWError(err, ""),
				Data:     nil,
			})
			return
		}

		respPlans := make([]types.VipPlan, 0, len(rows))
		for _, plan := range rows {
			respPlans = append(respPlans, common.VipPlanModelToTypes(plan))
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetVipPlansResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP套餐列表成功"),
			Data:     respPlans,
		})
	}
}
