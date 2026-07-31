package adminbiz

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	adminv1 "backend/api/admin/v1"
	platformv1 "backend/api/platform/v1"
	"backend/model"

	"gorm.io/gorm"
)

// UpsertAppReleaseInput 管理台保存 App 版本配置。
type UpsertAppReleaseInput struct {
	Platform    string
	VersionName string
	VersionCode int64
	ApkURL      string
	Changelog   string
	ForceUpdate bool
	Enabled     bool
	UpdatedBy   uint
}

// GetAppRelease 读取某平台配置；未配置时 configured=false。
func GetAppRelease(ctx context.Context, store AdminStore, platform string) (*adminv1.AdminGetAppReleaseResp, error) {
	platform = normalizePlatform(platform)
	row, err := store.GetAppReleaseByPlatform(ctx, platform)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return &adminv1.AdminGetAppReleaseResp{
				Configured: false,
				Release: &adminv1.AdminAppRelease{
					Platform: platform,
					Enabled:  false,
				},
			}, nil
		}
		return nil, fmt.Errorf("get app release %s: %w", platform, err)
	}
	return &adminv1.AdminGetAppReleaseResp{
		Configured: true,
		Release:    appReleaseToAdminProto(row),
	}, nil
}

// UpsertAppRelease 按平台创建或更新版本配置。
func UpsertAppRelease(ctx context.Context, store AdminStore, in UpsertAppReleaseInput) (*adminv1.AdminUpsertAppReleaseResp, error) {
	platform := normalizePlatform(in.Platform)
	versionName := strings.TrimSpace(in.VersionName)
	apkURL := strings.TrimSpace(in.ApkURL)
	if versionName == "" {
		return nil, fmt.Errorf("version_name is required")
	}
	if in.VersionCode <= 0 {
		return nil, fmt.Errorf("version_code must be > 0")
	}
	if err := validateApkURL(apkURL); err != nil {
		return nil, err
	}

	row, err := store.GetAppReleaseByPlatform(ctx, platform)
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, fmt.Errorf("get app release %s: %w", platform, err)
	}

	now := time.Now()
	if err == gorm.ErrRecordNotFound {
		row = model.AppRelease{
			Platform:    platform,
			VersionName: versionName,
			VersionCode: in.VersionCode,
			ApkURL:      apkURL,
			Changelog:   strings.TrimSpace(in.Changelog),
			ForceUpdate: in.ForceUpdate,
			Enabled:     in.Enabled,
			UpdatedBy:   in.UpdatedBy,
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := store.CreateAppRelease(ctx, &row); err != nil {
			return nil, fmt.Errorf("create app release: %w", err)
		}
		return &adminv1.AdminUpsertAppReleaseResp{Release: appReleaseToAdminProto(row)}, nil
	}

	row.VersionName = versionName
	row.VersionCode = in.VersionCode
	row.ApkURL = apkURL
	row.Changelog = strings.TrimSpace(in.Changelog)
	row.ForceUpdate = in.ForceUpdate
	row.Enabled = in.Enabled
	row.UpdatedBy = in.UpdatedBy
	row.UpdatedAt = now
	if err := store.SaveAppRelease(ctx, &row); err != nil {
		return nil, fmt.Errorf("save app release: %w", err)
	}
	return &adminv1.AdminUpsertAppReleaseResp{Release: appReleaseToAdminProto(row)}, nil
}

// GetLatestAppReleasePublic 客户端拉取已启用的最新配置。
func GetLatestAppReleasePublic(ctx context.Context, store AdminStore, platform string) (*platformv1.GetLatestAppReleaseResp, error) {
	platform = normalizePlatform(platform)
	row, err := store.GetAppReleaseByPlatform(ctx, platform)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return &platformv1.GetLatestAppReleaseResp{Available: false, Platform: platform}, nil
		}
		return nil, fmt.Errorf("get app release %s: %w", platform, err)
	}
	if !row.Enabled || strings.TrimSpace(row.ApkURL) == "" || row.VersionCode <= 0 {
		return &platformv1.GetLatestAppReleaseResp{Available: false, Platform: platform}, nil
	}
	return &platformv1.GetLatestAppReleaseResp{
		Available:   true,
		Platform:    row.Platform,
		VersionName: row.VersionName,
		VersionCode: row.VersionCode,
		ApkUrl:      row.ApkURL,
		Changelog:   row.Changelog,
		ForceUpdate: row.ForceUpdate,
	}, nil
}

func normalizePlatform(platform string) string {
	p := strings.ToLower(strings.TrimSpace(platform))
	if p == "" {
		return model.AppReleasePlatformAndroid
	}
	return p
}

func validateApkURL(raw string) error {
	if raw == "" {
		return fmt.Errorf("apk_url is required")
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return fmt.Errorf("apk_url must be a valid http(s) URL")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return fmt.Errorf("apk_url must use http or https")
	}
	return nil
}

func appReleaseToAdminProto(row model.AppRelease) *adminv1.AdminAppRelease {
	updatedBy := ""
	if row.UpdatedBy > 0 {
		updatedBy = fmt.Sprintf("%d", row.UpdatedBy)
	}
	return &adminv1.AdminAppRelease{
		Platform:    row.Platform,
		VersionName: row.VersionName,
		VersionCode: row.VersionCode,
		ApkUrl:      row.ApkURL,
		Changelog:   row.Changelog,
		ForceUpdate: row.ForceUpdate,
		Enabled:     row.Enabled,
		UpdatedAt:   row.UpdatedAt.Format(time.RFC3339),
		UpdatedBy:   updatedBy,
	}
}
