//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
	vipbiz "backend/internal/biz/vip"
)

func AdminCreateVipPlanHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminCreateVipPlanReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminCreateVipPlanReq) (resp *types.AdminCreateVipPlanResp, err error) {
			if strings.TrimSpace(req.Name) == "" {
			return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "套餐名称不能为空"},
			}, nil
			}
			if req.DurationDays <= 0 {
			return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "有效期天数必须大于 0"},
			}, nil
			}
			if req.Price < 0 {
			return &types.AdminCreateVipPlanResp{
			BaseResp: types.BaseResp{Success: false, Message: "价格不能为负数"},
			}, nil
			}

			plan, err := svcCtx.VipGW.CreatePlan(ctx, vipbiz.CreatePlanInput{
			Name:         strings.TrimSpace(req.Name),
			Description:  strings.TrimSpace(req.Description),
			Price:        req.Price,
			DurationDays: req.DurationDays,
			})
			if err != nil {
			return &types.AdminCreateVipPlanResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			resp = &types.AdminCreateVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.VipPlanModelToTypes(plan),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "vip_plan", resp.Data.Id, "创建 VIP 套餐")
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
