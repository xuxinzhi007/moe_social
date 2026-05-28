package moesocial

import (
	"strconv"
	"strings"

	"github.com/spf13/viper"
)

const (
	defaultUnifiedConfig = "config/config.yaml"
	defaultAPIFragment   = "api/etc/moe.yaml"
	defaultRPCFragment   = "rpc/etc/moe.yaml"
)

// StartupPaths PK-13：统一配置入口 + API/RPC 结构片段路径。
type StartupPaths struct {
	Unified     string
	APIFragment string
	RPCFragment string
}

// ResolveStartupPaths 解析启动配置路径（-f 为 SSOT；片段可由 config.yaml runtime 段覆盖）。
func ResolveStartupPaths(unified, apiOverride, rpcOverride string) StartupPaths {
	u := strings.TrimSpace(unified)
	if u == "" {
		u = defaultUnifiedConfig
	}
	api := strings.TrimSpace(apiOverride)
	rpc := strings.TrimSpace(rpcOverride)
	if api != "" && rpc != "" {
		return StartupPaths{Unified: u, APIFragment: api, RPCFragment: rpc}
	}
	v := viperForUnified(u)
	if api == "" {
		api = strings.TrimSpace(v.GetString("runtime.api_config_fragment"))
		if api == "" {
			api = defaultAPIFragment
		}
	}
	if rpc == "" {
		rpc = strings.TrimSpace(v.GetString("runtime.rpc_config_fragment"))
		if rpc == "" {
			rpc = defaultRPCFragment
		}
	}
	return StartupPaths{Unified: u, APIFragment: api, RPCFragment: rpc}
}

// NormalizeOptions 填充 Options 的配置路径（Run 入口调用）。
func (o *Options) NormalizeOptions() {
	if o == nil {
		return
	}
	p := ResolveStartupPaths(o.UnifiedConfigFile, o.APIConfigFile, o.RPCConfigFile)
	o.UnifiedConfigFile = p.Unified
	o.APIConfigFile = p.APIFragment
	o.RPCConfigFile = p.RPCFragment
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

func grpcListenFromUnified(unified string) string {
	v := viperForUnified(unified)
	if s := strings.TrimSpace(v.GetString("runtime.grpc_listen")); s != "" {
		return s
	}
	port := strings.TrimSpace(v.GetString("moe.production.internal_grpc_port"))
	if port == "" {
		return ""
	}
	if strings.Contains(port, ":") {
		return port
	}
	return "0.0.0.0:" + port
}
