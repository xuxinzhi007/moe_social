package moewiring

import (
	"strings"
	"sync"

	"backend/internal/platform/moeconf"

	"github.com/spf13/viper"
)

var (
	configOnce sync.Once
	configV    *viper.Viper
)

func moeViper() *viper.Viper {
	configOnce.Do(func() {
		v := viper.New()
		v.SetConfigName("config")
		v.SetConfigType("yaml")
		v.AddConfigPath("./config")
		v.AddConfigPath("../config")
		v.AddConfigPath("../../config")
		_ = v.ReadInConfig()
		configV = v
	})
	return configV
}

func boolOr(v *viper.Viper, keys []string, def bool) bool {
	if v == nil {
		return def
	}
	for _, key := range keys {
		if v.IsSet(key) {
			return v.GetBool(key)
		}
	}
	return def
}

// APIInProcessEnabled config.yaml: moe.api_in_process
func APIInProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.api_in_process"}, false)
}

// RegisterMoeGRPCEnabled config.yaml: moe.register_moe_grpc（兼容旧键 register_v1_grpc）
func RegisterMoeGRPCEnabled() bool {
	return boolOr(moeViper(), []string{"moe.register_moe_grpc", "moe.register_v1_grpc"}, true)
}

// UseMoeGRPCEnabled config.yaml: moe.use_moe_grpc（兼容旧键 use_v1_grpc）
func UseMoeGRPCEnabled() bool {
	return boolOr(moeViper(), []string{"moe.use_moe_grpc", "moe.use_v1_grpc"}, true)
}

// SingleProcessEnabled 使用 cmd/moe-social 单进程时建议为 true（强制 api_in_process 语义）。
func SingleProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.single_process"}, false)
}

// KratosAdminHTTPEnabled config.yaml: moe.kratos_admin_http_enabled（Phase 3；Phase 4 可读 Bootstrap）
func KratosAdminHTTPEnabled() bool {
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_admin_http_enabled") {
		return b.GetMoe().GetKratosAdminHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_admin_http_enabled"}, false)
}

// UserAPIInProcessEnabled config.yaml: moe.user_api_in_process（默认随 api_in_process / single_process 开启）
func UserAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.user_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.user_api_in_process"}, false)
}

// VIPAPIInProcessEnabled config.yaml: moe.vip_api_in_process（默认随 api_in_process / single_process 开启）
func VIPAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.vip_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.vip_api_in_process"}, false)
}

// KratosVipHTTPEnabled config.yaml: moe.kratos_vip_http_enabled（PK-2 VIP ListPlans 灰度）
func KratosVipHTTPEnabled() bool {
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_vip_http_enabled") {
		return b.GetMoe().GetKratosVipHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_vip_http_enabled"}, false)
}

// KratosPilotBaseURL 纯 Kratos 试点 HTTP 基址（Moe/VIP 灰度共用）。
func KratosPilotBaseURL() string {
	return KratosAdminBaseURL()
}

// KratosAdminBaseURL config.yaml: moe.kratos_admin_base_url（默认 moe-kratos HTTP）
func KratosAdminBaseURL() string {
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil {
		if u := strings.TrimSpace(b.GetMoe().GetKratosAdminBaseUrl()); u != "" {
			return u
		}
	}
	v := moeViper()
	if v == nil {
		return "http://127.0.0.1:19032"
	}
	if v.IsSet("moe.kratos_admin_base_url") {
		return v.GetString("moe.kratos_admin_base_url")
	}
	return "http://127.0.0.1:19032"
}
