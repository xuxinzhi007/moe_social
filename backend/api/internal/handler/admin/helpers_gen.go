//go:build hybrid

package admin

import (
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"
	"strings"
)

func modelInList(id string, models []string) bool {
	for _, m := range models {
		if strings.EqualFold(strings.TrimSpace(m), strings.TrimSpace(id)) {
			return true
		}
	}
	return false
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
