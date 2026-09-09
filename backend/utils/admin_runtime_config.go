package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"backend/pkg/conf"

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
// 用 Reload 而不是 Get：这个视图要反映磁盘上的当前值，包括运维手改文件的情况
// （迁移前每次都新开一个 viper 读盘，语义等价；管理台是低频端点，读盘开销可接受）。
func ReadRuntimeConfig() (RuntimeConfigView, error) {
	cfg, err := conf.Reload()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	return RuntimeConfigView{
		PublicApiBaseUrl:   trimURL(cfg.AppClient.PublicAPIBaseURL),
		ApiPublicBaseUrl:   trimURL(cfg.API.PublicBaseURL),
		ImagePublicBaseUrl: trimURL(cfg.Image.PublicBaseURL),
		ImageLocalDir:      strings.TrimSpace(cfg.Image.LocalDir),
		ImageMaxBytes:      cfg.Image.MaxBytes,
		ConfigFile:         conf.Path(),
	}, nil
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
		// 键名必须是 config.yaml 实际使用的蛇形键；写成 Image.PublicBaseUrl 会被 viper
		// 小写化为无下划线的 publicbaseurl 死键，运行时优先读 public_base_url，改动静默丢失。
		v.Set("image.public_base_url", trimURL(*patch.ImagePublicBaseUrl))
	}
	if patch.ImageLocalDir != nil {
		v.Set("image.local_dir", strings.TrimSpace(*patch.ImageLocalDir))
	}
	if patch.ImageMaxBytes != nil {
		v.Set("image.max_bytes", *patch.ImageMaxBytes)
	}
	if err := v.WriteConfig(); err != nil {
		return RuntimeConfigView{}, fmt.Errorf("写入配置失败: %w", err)
	}
	// pkg/conf 没有 setter，写回只能留在 viper；但写完必须让进程内的缓存指向刚写的文件，
	// 否则其余读者到重启前都看不到本次改动 —— load.go:114 的注释就是这条要求，
	// 而 Reload 在此之前一直是零调用方。
	if _, err := conf.LoadFile(path); err != nil {
		return RuntimeConfigView{}, fmt.Errorf("重载配置失败: %w", err)
	}
	view, err := ReadRuntimeConfig()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	view.ConfigFile = path
	return view, nil
}
