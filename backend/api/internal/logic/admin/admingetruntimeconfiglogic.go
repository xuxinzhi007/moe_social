package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetRuntimeConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetRuntimeConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetRuntimeConfigLogic {
	return &AdminGetRuntimeConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetRuntimeConfigLogic) AdminGetRuntimeConfig(_ *types.EmptyReq) (*types.AdminRuntimeConfigResp, error) {
	view, err := utils.ReadRuntimeConfig()
	if err != nil {
		l.Errorf("[admin] read runtime config: %v", err)
		return &types.AdminRuntimeConfigResp{
			BaseResp: common.HandleError(err),
		}, nil
	}
	return &types.AdminRuntimeConfigResp{
		BaseResp: common.HandleError(nil),
		Data:     runtimeConfigToTypes(view, l.svcCtx),
	}, nil
}

func runtimeConfigToTypes(view utils.RuntimeConfigView, svcCtx *svc.ServiceContext) types.AdminRuntimeConfigData {
	data := types.AdminRuntimeConfigData{
		PublicApiBaseUrl:   view.PublicApiBaseUrl,
		ApiPublicBaseUrl:   view.ApiPublicBaseUrl,
		ImagePublicBaseUrl: view.ImagePublicBaseUrl,
		ImageLocalDir:      view.ImageLocalDir,
		ImageMaxBytes:      view.ImageMaxBytes,
		ConfigFile:         view.ConfigFile,
		RequiresRestart:    false,
	}
	if data.PublicApiBaseUrl == "" {
		data.PublicApiBaseUrl = svcCtx.Config.ClientPublicApiBaseUrl
	}
	if data.ImagePublicBaseUrl == "" {
		data.ImagePublicBaseUrl = svcCtx.Config.Image.PublicBaseUrl
	}
	if data.ImageLocalDir == "" {
		data.ImageLocalDir = svcCtx.Config.Image.LocalDir
	}
	if data.ImageMaxBytes == 0 {
		data.ImageMaxBytes = svcCtx.Config.Image.MaxBytes
	}
	return data
}
