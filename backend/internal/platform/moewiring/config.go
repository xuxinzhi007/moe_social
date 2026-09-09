package moewiring

import (
	"sync"

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

func UserAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.user_api_in_process")
}

func VIPAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.vip_api_in_process")
}

// 这里曾有一族 go-zero→Kratos 迁移期的过渡开关（KratosPureEnabled / KratosHTTPFrontEnabled /
// KratosGRPCManaged / KratosSuperGRPCNative / KratosHybridHTTPFallback / SuperGrpcRetired /
// KratosPK8GoctlRetired / PilotProcessDeprecated / KratosInternalHTTPPort / Kratos*HTTPEnabled /
// KratosAdminBaseURL 等，共 15 个），2026-09-08 全部删除。
//
// 删除依据（逐个实测调用方，不是看 grep 命中）：
//   - 8 个零调用方；KratosPK8GoctlRetired 的唯一调用方本身也是死的；
//     KratosPureEnabled 的 5 个「调用方」全在这族死函数内部。
//   - KratosAdmin/Vip/AdminInsights HTTPEnabled 三个只被 wiring/wire_mode.go 的四个薄封装用，
//     而那四个只被 wireKratosNotes 用——该函数只往启动日志写 note，且三闸恒为 false
//     （对应 yaml 键根本不存在），所以它一条 note 都没输出过。
//
// 连带效果：moeconf.LoadBootstrap() 的 4 个调用方全在上述死函数里，该包已于 2026-09-09 整包删除。
// 随之删除的还有它唯一的产物 internal/conf/moe/v1（proto 无任何 import 者，生成链 gen-moe-conf 一并退役）、
// config.yaml 的 moe.kratos_pure_enabled / moe.kratos_admin_base_url 两个空转键，
// 以及 pkg/conf 里对应的 9 个 Kratos* 字段、MoePilot 与 4 个 Kratos* 派生方法（含其专属用例 TestKratosGates）。
// 18888 / 19032 两个无监听者端口的硬编码兜底也随之消失。
