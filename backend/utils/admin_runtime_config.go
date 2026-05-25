package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/viper"
)

// RuntimeConfigView 供 Moe Admin 展示/编辑的非敏感运行时配置。
type RuntimeConfigView struct {
	PublicApiBaseUrl   string `json:"public_api_base_url"`
	ApiPublicBaseUrl   string `json:"api_public_base_url"`
	ImagePublicBaseUrl string `json:"image_public_base_url"`
	ImageLocalDir      string `json:"image_local_dir"`
	ImageMaxBytes      int64  `json:"image_max_bytes"`
	ConfigFile         string `json:"config_file"`
}

// RuntimeConfigPatch 按字段增量更新 config.yaml。
type RuntimeConfigPatch struct {
	PublicApiBaseUrl        *string
	ApiPublicBaseUrl        *string
	ImagePublicBaseUrl      *string
	ImageLocalDir           *string
	ImageMaxBytes           *int64
}

func resolveUnifiedConfigPath() (string, error) {
	candidates := []string{
		"./config/config.yaml",
		"../config/config.yaml",
		"../../config/config.yaml",
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			abs, err := filepath.Abs(p)
			if err != nil {
				return p, nil
			}
			return abs, nil
		}
	}
	return "", fmt.Errorf("未找到 backend/config/config.yaml")
}

func newUnifiedConfigViper() (*viper.Viper, string, error) {
	path, err := resolveUnifiedConfigPath()
	if err != nil {
		return nil, "", err
	}
	v := viper.New()
	v.SetConfigFile(path)
	if err := v.ReadInConfig(); err != nil {
		return nil, path, err
	}
	return v, path, nil
}

func trimURL(u string) string {
	u = strings.TrimSpace(u)
	for strings.HasSuffix(u, "/") {
		u = strings.TrimSuffix(u, "/")
	}
	return u
}

// ReadRuntimeConfig 读取统一 config.yaml 中的 App/图片相关配置。
func ReadRuntimeConfig() (RuntimeConfigView, error) {
	v, path, err := newUnifiedConfigViper()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	view := RuntimeConfigView{
		PublicApiBaseUrl:   trimURL(v.GetString("app_client.public_api_base_url")),
		ApiPublicBaseUrl:   trimURL(firstViperString(v, "api.public_base_url")),
		ImagePublicBaseUrl: trimURL(firstViperString(v, "image.public_base_url", "Image.PublicBaseUrl")),
		ImageLocalDir:      strings.TrimSpace(firstViperString(v, "image.local_dir", "Image.LocalDir")),
		ImageMaxBytes:      firstViperInt64(v, "image.max_bytes", "Image.MaxBytes"),
		ConfigFile:         path,
	}
	return view, nil
}

// ApplyRuntimeConfigPatch 写入 config.yaml 并返回最新视图。
func ApplyRuntimeConfigPatch(patch RuntimeConfigPatch) (RuntimeConfigView, error) {
	v, path, err := newUnifiedConfigViper()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	if patch.PublicApiBaseUrl != nil {
		v.Set("app_client.public_api_base_url", trimURL(*patch.PublicApiBaseUrl))
	}
	if patch.ApiPublicBaseUrl != nil {
		v.Set("api.public_base_url", trimURL(*patch.ApiPublicBaseUrl))
	}
	if patch.ImagePublicBaseUrl != nil {
		v.Set("Image.PublicBaseUrl", trimURL(*patch.ImagePublicBaseUrl))
	}
	if patch.ImageLocalDir != nil {
		v.Set("Image.LocalDir", strings.TrimSpace(*patch.ImageLocalDir))
	}
	if patch.ImageMaxBytes != nil {
		v.Set("Image.MaxBytes", *patch.ImageMaxBytes)
	}
	if err := v.WriteConfig(); err != nil {
		return RuntimeConfigView{}, fmt.Errorf("写入配置失败: %w", err)
	}
	view, err := ReadRuntimeConfig()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	view.ConfigFile = path
	return view, nil
}

func firstViperString(v *viper.Viper, keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(v.GetString(key)); value != "" {
			return value
		}
	}
	return ""
}

func firstViperInt64(v *viper.Viper, keys ...string) int64 {
	for _, key := range keys {
		if v.IsSet(key) {
			return v.GetInt64(key)
		}
	}
	return 0
}
