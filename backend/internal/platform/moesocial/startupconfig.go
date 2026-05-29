package moesocial

import (
	"strconv"
	"strings"

	"github.com/spf13/viper"
)

const (
	defaultUnifiedConfig = "config/config.yaml"
	defaultAPIFragment   = "api/etc/moe.yaml"
)

// StartupPaths PK-13：统一配置入口 + API 结构片段路径。
type StartupPaths struct {
	Unified     string
	APIFragment string
}

// ResolveStartupPaths 解析启动配置路径（-f 为 SSOT；片段可由 config.yaml runtime 段覆盖）。
func ResolveStartupPaths(unified, apiOverride string) StartupPaths {
	u := strings.TrimSpace(unified)
	if u == "" {
		u = defaultUnifiedConfig
	}
	api := strings.TrimSpace(apiOverride)
	if api != "" {
		return StartupPaths{Unified: u, APIFragment: api}
	}
	v := viperForUnified(u)
	api = strings.TrimSpace(v.GetString("runtime.api_config_fragment"))
	if api == "" {
		api = defaultAPIFragment
	}
	return StartupPaths{Unified: u, APIFragment: api}
}

// NormalizeOptions 填充 Options 的配置路径（Run 入口调用）。
func (o *Options) NormalizeOptions() {
	if o == nil {
		return
	}
	p := ResolveStartupPaths(o.UnifiedConfigFile, o.APIConfigFile)
	o.UnifiedConfigFile = p.Unified
	o.APIConfigFile = p.APIFragment
}

func viperForUnified(unified string) *viper.Viper {
	v := viper.New()
	v.SetConfigType("yaml")
	path := strings.TrimSpace(unified)
	if path == "" {
		path = defaultUnifiedConfig
	}
	v.SetConfigFile(path)
	if err := v.ReadInConfig(); err != nil {
		v.SetConfigName("config")
		v.SetConfigType("yaml")
		v.AddConfigPath("./config")
		v.AddConfigPath("../config")
		v.AddConfigPath("../../config")
		_ = v.ReadInConfig()
	}
	return v
}

func httpPortFromUnified(unified string) int {
	v := viperForUnified(unified)
	if p := v.GetInt("runtime.http_port"); p > 0 {
		return p
	}
	if s := strings.TrimSpace(v.GetString("moe.production.external_http_port")); s != "" {
		if p, err := strconv.Atoi(s); err == nil && p > 0 {
			return p
		}
	}
	return 0
}
