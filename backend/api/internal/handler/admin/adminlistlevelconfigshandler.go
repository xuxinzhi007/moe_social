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

func AdminListLevelConfigsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := func(req *types.EmptyReq) (*types.AdminListLevelConfigsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListLevelConfigs(ctx, &moe.AdminListLevelConfigsReq{})
			if err != nil {
			return &types.AdminListLevelConfigsResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			items := make([]types.AdminLevelConfigItem, len(rpcResp.GetItems()))
			for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminLevelConfigToTypes(item)
			}
			return &types.AdminListLevelConfigsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
