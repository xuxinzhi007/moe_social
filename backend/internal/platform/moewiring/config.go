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

// KratosAdminHTTPEnabled config.yaml: moe.kratos_admin_http_enabled（Moe Admin 读灰度）
func KratosAdminHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
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

// KratosPilotReadEnabled 一键开启 Moe/VIP/Insights 读路径灰度（PK-3 团队联调）。
func KratosPilotReadEnabled() bool {
	return boolOr(moeViper(), []string{"moe.kratos_pilot_read_enabled"}, false)
}

// KratosVipHTTPEnabled config.yaml: moe.kratos_vip_http_enabled（PK-2 VIP ListPlans 灰度）
func KratosVipHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_vip_http_enabled") {
		return b.GetMoe().GetKratosVipHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_vip_http_enabled"}, false)
}

// KratosAdminInsightsHTTPEnabled PK-3 Admin Insights 读灰度到 :19032。
func KratosAdminInsightsHTTPEnabled() bool {
	if KratosPilotReadEnabled() {
		return true
	}
	if b, err := moeconf.LoadBootstrap(); err == nil && b.GetMoe() != nil && moeViper().IsSet("moe.kratos_admin_insights_http_enabled") {
		return b.GetMoe().GetKratosAdminInsightsHttpEnabled()
	}
	return boolOr(moeViper(), []string{"moe.kratos_admin_insights_http_enabled"}, false)
}

// KratosPureEnabled PK-8/9：生产默认纯 Kratos（HTTP :8888 + gRPC 由 kratos.App，无 go-zero 对外）。
func KratosPureEnabled() bool {
	return boolOr(moeViper(), []string{"moe.kratos_pure_enabled"}, false)
}

// KratosHTTPFrontEnabled PK-4：moe-social 对外 Kratos HTTP :8888 + go-zero 内网回退。
func KratosHTTPFrontEnabled() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_http_front_enabled"}, false)
}

// KratosGRPCManaged PK-7：zrpc 由 kratos.App 统一启停（与 co transport/grpc 对齐）。
func KratosGRPCManaged() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_grpc_managed"}, false)
}

// KratosPureHTTPWithoutLegacy 纯 Kratos 且不启动 go-zero rest（仅 Wire Svc）。
func KratosPureHTTPWithoutLegacy() bool {
	return KratosPureEnabled()
}

// KratosPK8GoctlRetired PK-8：默认不再执行 make gen-api；HTTP 由 moekratospilot 注册。
func KratosPK8GoctlRetired() bool {
	if KratosPureEnabled() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_pk8_goctl_retired"}, true)
}

// KratosHybridHTTPFallback PK-8 后是否允许 go-zero rest 回退路径（仅紧急回滚）。
func KratosHybridHTTPFallback() bool {
	if KratosPureEnabled() {
		return false
	}
	if !KratosPK8GoctlRetired() {
		return true
	}
	return boolOr(moeViper(), []string{"moe.kratos_hybrid_http_fallback"}, false)
}

// PilotProcessDeprecated PK-10：:1903x 试点进程已收敛到 make moe-social :8888。
func PilotProcessDeprecated() bool {
	return boolOr(moeViper(), []string{"moe.pilot_process_deprecated"}, true)
}

// KratosInternalHTTPPort PK-4 内网 go-zero 端口（默认 18888）。
func KratosInternalHTTPPort() int {
	v := moeViper()
	if v != nil && v.IsSet("moe.kratos_internal_http_port") {
		if p := v.GetInt("moe.kratos_internal_http_port"); p > 0 {
			return p
		}
	}
	return 18888
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
