package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateRuntimeConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateRuntimeConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateRuntimeConfigLogic {
	return &AdminUpdateRuntimeConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateRuntimeConfigLogic) AdminUpdateRuntimeConfig(req *types.AdminUpdateRuntimeConfigReq) (*types.AdminUpdateRuntimeConfigResp, error) {
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
		l.Errorf("[admin] update runtime config: %v", err)
		return &types.AdminUpdateRuntimeConfigResp{
			BaseResp: common.HandleError(err),
		}, nil
	}

	// 同步内存配置，使 client-config / 图片 URL 拼接立即生效（无需重启）。
	if patch.PublicApiBaseUrl != nil {
		l.svcCtx.Config.ClientPublicApiBaseUrl = view.PublicApiBaseUrl
	}
	if patch.ImagePublicBaseUrl != nil {
		l.svcCtx.Config.Image.PublicBaseUrl = view.ImagePublicBaseUrl
	}
	if patch.ImageLocalDir != nil {
		l.svcCtx.Config.Image.LocalDir = view.ImageLocalDir
	}
	if patch.ImageMaxBytes != nil {
		l.svcCtx.Config.Image.MaxBytes = view.ImageMaxBytes
	}

	resp := &types.AdminUpdateRuntimeConfigResp{
		BaseResp: common.HandleError(nil),
		Data:     runtimeConfigToTypes(view, l.svcCtx),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "runtime_config", "", "更新运行时配置")
	}
	return resp, nil
}
