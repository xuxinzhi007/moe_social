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

func AdminUpsertMenuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpsertMenuReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpsertMenuReq) (*types.AdminUpsertMenuResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpsertMenu(ctx, &moe.AdminUpsertMenuReq{
			Key:          req.Key,
			Kind:         req.Kind,
			ParentKey:    req.ParentKey,
			Path:         req.Path,
			Label:        req.Label,
			Icon:         req.Icon,
			Caption:      req.Caption,
			Status:       req.Status,
			AppDomain:    req.AppDomain,
			SortOrder:    int32(req.SortOrder),
			DefaultOpen:  req.DefaultOpen,
			End:          req.End,
			ExternalHref: req.ExternalHref,
			Enabled:      req.Enabled,
			})
			if err != nil {
			return &types.AdminUpsertMenuResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpsertMenuResp{
			BaseResp: common.HandleRPCError(nil, "保存成功"),
			Data:     common.RpcAdminMenuToTypes(rpcResp.GetMenu()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "upsert", "admin_menu", req.Key, "保存侧栏菜单")
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
