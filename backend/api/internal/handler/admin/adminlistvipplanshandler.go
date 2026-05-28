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

func AdminListVipPlansHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, br := common.RequireAdminToken(r); br != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminListVipPlansResp{BaseResp: *br})
			return
		}
		var req types.AdminListVipPlansReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminListVipPlansReq) (resp *types.AdminListVipPlansResp, err error) {
			page := req.Page
			if page <= 0 {
			page = 1
			}
			pageSize := req.PageSize
			if pageSize <= 0 {
			pageSize = 50
			}

			rows, total, err := svcCtx.VipGW.ListPlans(r.Context(), vipbiz.ListPlansFilter{
			Page:           page,
			PageSize:       pageSize,
			Keyword:        req.Keyword,
			IncludeDeleted: req.IncludeDeleted,
			})
			if err != nil {
			return &types.AdminListVipPlansResp{
			BaseResp: common.HandleVipGWError(err, ""),
			}, nil
			}

			items := make([]types.VipPlan, 0, len(rows))
			for _, p := range rows {
			items = append(items, common.VipPlanModelToTypes(p))
			}

			return &types.AdminListVipPlansResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminListVipPlansData{
			Items: items,
			Total: int(total),
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
