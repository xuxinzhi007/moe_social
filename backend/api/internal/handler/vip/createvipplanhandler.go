//go:build hybrid

package vip

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CreateVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CreateVipPlanResp{BaseResp: *br})
			return
		}

		var req types.CreateVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		plan, err := svcCtx.VipGW.CreatePlan(r.Context(), vipbiz.CreatePlanInput{
			Name:         req.Name,
			Description:  req.Description,
			Price:        req.Price,
			DurationDays: req.DurationDays,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CreateVipPlanResp{
				BaseResp: common.HandleVipGWError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CreateVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "创建VIP套餐成功"),
			Data:     common.VipPlanModelToTypes(plan),
		})
	}
}
