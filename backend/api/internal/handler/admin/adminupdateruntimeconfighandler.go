//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"
	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateRuntimeConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateRuntimeConfigReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateRuntimeConfigReq) (*types.AdminUpdateRuntimeConfigResp, error) {
			patch := utils.RuntimeConfigPatch{}
			if req.UpdatePublicApiBaseUrl {
			v := req.PublicApiBaseUrl
			patch.PublicApiBaseUrl = &v
			}
			if req.UpdateApiPublicBaseUrl {
			v := req.ApiPublicBaseUrl
			patch.ApiPublicBaseUrl = &v
			}
			if req.UpdateImagePublicBaseUrl {
			v := req.ImagePublicBaseUrl
			patch.ImagePublicBaseUrl = &v
			}
			if req.UpdateImageLocalDir {
			v := req.ImageLocalDir
			patch.ImageLocalDir = &v
			}
			if req.UpdateImageMaxBytes {
			v := req.ImageMaxBytes
			patch.ImageMaxBytes = &v
			}

			view, err := utils.ApplyRuntimeConfigPatch(patch)
			if err != nil {
			logx.WithContext(ctx).Errorf("[admin] update runtime config: %v", err)
			return &types.AdminUpdateRuntimeConfigResp{
			BaseResp: common.HandleError(err),
			}, nil
			}

			// 同步内存配置，使 client-config / 图片 URL 拼接立即生效（无需重启）。
			if patch.PublicApiBaseUrl != nil {
			svcCtx.Config.ClientPublicApiBaseUrl = view.PublicApiBaseUrl
			}
			if patch.ImagePublicBaseUrl != nil {
			svcCtx.Config.Image.PublicBaseUrl = view.ImagePublicBaseUrl
			}
			if patch.ImageLocalDir != nil {
			svcCtx.Config.Image.LocalDir = view.ImageLocalDir
			}
			if patch.ImageMaxBytes != nil {
			svcCtx.Config.Image.MaxBytes = view.ImageMaxBytes
			}

			resp := &types.AdminUpdateRuntimeConfigResp{
			BaseResp: common.HandleError(nil),
			Data:     runtimeConfigToTypes(view, svcCtx),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "runtime_config", "", "更新运行时配置")
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
