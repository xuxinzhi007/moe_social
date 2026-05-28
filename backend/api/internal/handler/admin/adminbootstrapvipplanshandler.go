package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminBootstrapVipPlansHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := func(req *types.EmptyReq) (resp *types.AdminBootstrapVipPlansResp, err error) {
			created, err := svcCtx.VipGW.BootstrapPlans(ctx)
			if err != nil {
			return &types.AdminBootstrapVipPlansResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			msg := "ok"
			if created > 0 {
			msg = "已导入默认套餐"
			} else {
			msg = "已有套餐，未导入"
			}

			resp = &types.AdminBootstrapVipPlansResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data: types.AdminBootstrapVipPlansData{
			Created: created,
			},
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "bootstrap", "vip_plan", "", "导入默认 VIP 套餐")
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
