//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	vipbiz "backend/internal/biz/vip"
)

func AdminUpdateVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateVipPlanReq) (*types.AdminUpdateVipPlanResp, error) {
			plan, err := svcCtx.VipGW.UpdatePlan(ctx, req.PlanId, vipbiz.UpdatePlanPatch{
			Name:               req.Name,
			Description:        req.Description,
			Price:              req.Price,
			DurationDays:       req.DurationDays,
			UpdateName:         req.UpdateName,
			UpdateDescription:  req.UpdateDescription,
			UpdatePrice:        req.UpdatePrice,
			UpdateDurationDays: req.UpdateDurationDays,
			})
			if err != nil {
			return &types.AdminUpdateVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			resp := &types.AdminUpdateVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.VipPlanModelToTypes(plan),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "vip_plan", req.PlanId, "更新 VIP 套餐")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
