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

func defaultInProcessEnabled() bool {
	return SingleProcessEnabled() || APIInProcessEnabled()
}

func domainInProcessEnabled(key string) bool {
	return boolOr(moeViper(), []string{key}, defaultInProcessEnabled())
}

// APIInProcessEnabled reports whether legacy in-process app wiring remains enabled.
func APIInProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.api_in_process"}, false)
}

// SingleProcessEnabled reports whether the repo standard single-process moe-social mode is on.
func SingleProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.single_process"}, false)
}

// KratosAdminHTTPEnabled config.yaml: moe.kratos_admin_http_enabled.
func KratosAdminHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_admin_http_enabled") {
		return b.GetMoe().GetKratosAdminHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_admin_http_enabled"}, false)
}

func UserAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.user_api_in_process")
}

func VIPAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.vip_api_in_process")
}

// KratosPilotReadEnabled enables unified pilot reads for admin, vip, and insights endpoints.
func KratosPilotReadEnabled() bool {
	return boolOr(moeViper(), []string{"moe.kratos_pilot_read_enabled"}, false)
}

// KratosVipHTTPEnabled config.yaml: moe.kratos_vip_http_enabled.
func KratosVipHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_vip_http_enabled") {
		return b.GetMoe().GetKratosVipHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_vip_http_enabled"}, false)
}

// KratosAdminInsightsHTTPEnabled config.yaml: moe.kratos_admin_insights_http_enabled.
func KratosAdminInsightsHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_admin_insights_http_enabled") {
		return b.GetMoe().GetKratosAdminInsightsHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_admin_insights_http_enabled"}, false)
}

// KratosPureEnabled is the current production-standard pure Kratos mode.
func KratosPureEnabled() bool {
	return boolOr(moeViper(), []string{"moe.kratos_pure_enabled"}, false)
}

func KratosHTTPFrontEnabled() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_http_front_enabled"}, false)
}

func KratosGRPCManaged() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_grpc_managed"}, false)
}

func KratosSuperGRPCNative() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_super_grpc_native"}, false)
}

func KratosPureHTTPWithoutLegacy() bool {
	return KratosPureEnabled()
}

func SuperGrpcRetired() bool {
	if SingleProcessEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.super_grpc_retired"}, true)
}

func KratosPK8GoctlRetired() bool {
	return true
}

func KratosHybridHTTPFallback() bool {
	if KratosPureEnabled() {
		return false
	}
	if !KratosPK8GoctlRetired() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_hybrid_http_fallback"}, false)
}

func PilotProcessDeprecated() bool {
	return boolOr(moeViper(), []string{"moe.pilot_process_deprecated"}, true)
}

func KratosInternalHTTPPort() int {
	v := moeViper()
	if v != nil && v.IsSet("moe.kratos_internal_http_port") {
		if p := v.GetInt("moe.kratos_internal_http_port"); p > 0 {
			return p
		}
	}
	return 18888
}

func KratosPilotBaseURL() string {
	return KratosAdminBaseURL()
}

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
