//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteVipPlanReq) (*types.AdminDeleteVipPlanResp, error) {
			err := svcCtx.VipGW.DeletePlan(ctx, req.PlanId)
			if err != nil {
			return &types.AdminDeleteVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			resp := &types.AdminDeleteVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "已删除"),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "vip_plan", req.PlanId, "删除 VIP 套餐")
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
