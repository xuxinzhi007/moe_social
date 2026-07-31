package adminapp

import (
	"context"

	adminv1 "backend/api/admin/v1"
	platformv1 "backend/api/platform/v1"
	adminbiz "backend/internal/biz/admin"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

// GetAppRelease 管理台读取 App 版本配置。
func (s *AppService) GetAppRelease(ctx context.Context, in *adminv1.AdminGetAppReleaseReq) (*adminv1.AdminGetAppReleaseResp, error) {
	out, err := adminbiz.GetAppRelease(ctx, s.store, in.GetPlatform())
	if err != nil {
		return nil, kerrors.InternalServer("APP_RELEASE_GET", err.Error())
	}
	return out, nil
}

// UpsertAppRelease 管理台保存 App 版本配置。
func (s *AppService) UpsertAppRelease(ctx context.Context, in *adminv1.AdminUpsertAppReleaseReq, adminID uint) (*adminv1.AdminUpsertAppReleaseResp, error) {
	out, err := adminbiz.UpsertAppRelease(ctx, s.store, adminbiz.UpsertAppReleaseInput{
		Platform:    in.GetPlatform(),
		VersionName: in.GetVersionName(),
		VersionCode: in.GetVersionCode(),
		ApkURL:      in.GetApkUrl(),
		Changelog:   in.GetChangelog(),
		ForceUpdate: in.GetForceUpdate(),
		Enabled:     in.GetEnabled(),
		UpdatedBy:   adminID,
	})
	if err != nil {
		return nil, kerrors.BadRequest("APP_RELEASE_INVALID", err.Error())
	}
	return out, nil
}

// GetLatestAppReleasePublic 客户端公开拉取最新版本。
func (s *AppService) GetLatestAppReleasePublic(ctx context.Context, in *platformv1.GetLatestAppReleaseReq) (*platformv1.GetLatestAppReleaseResp, error) {
	out, err := adminbiz.GetLatestAppReleasePublic(ctx, s.store, in.GetPlatform())
	if err != nil {
		return nil, kerrors.InternalServer("APP_RELEASE_PUBLIC", err.Error())
	}
	return out, nil
}
