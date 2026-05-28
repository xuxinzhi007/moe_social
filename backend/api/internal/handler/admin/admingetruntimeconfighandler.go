//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetRuntimeConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		resp, err := func(req *types.EmptyReq) (*types.AdminRuntimeConfigResp, error) {
			view, err := svcCtx.AdminGW.ReadRuntimeConfig()
			if err != nil {
			logx.WithContext(ctx).Errorf("[admin] read runtime config: %v", err)
			return &types.AdminRuntimeConfigResp{
			BaseResp: common.HandleError(err),
			}, nil
			}
			return &types.AdminRuntimeConfigResp{
			BaseResp: common.HandleError(nil),
			Data:     runtimeConfigToTypes(view, svcCtx),
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
