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

func AdminDeleteMenuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteMenuReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteMenuReq) (*types.AdminDeleteMenuResp, error) {
			_, err := svcCtx.AdminGW.AdminDeleteMenu(ctx, &moe.AdminDeleteMenuReq{
			MenuKey: req.MenuKey,
			})
			if err != nil {
			return &types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "admin_menu", req.MenuKey, "删除侧栏菜单")
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
