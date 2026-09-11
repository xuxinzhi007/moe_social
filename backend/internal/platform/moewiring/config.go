package moewiring

import (
	"backend/pkg/conf"
)

// 序4：本文件此前自己养了一个 viper 单例（configOnce + configV + moeViper()）和一个
// 通用的 boolOr(keys, def) 回退器，19 个 moe.<domain>_api_in_process 开关都从这里读。
// 那套东西与 pkg/conf 的 DomainInProcess 是同一件事的两份实现，且它硬编码 searchDirs，
// 因此看不见 cmd/moe-social 的 -f（§20.5 的 10 个文件之一）。现在只剩薄封装：
// 导出的 <Domain>APIInProcessEnabled() 保留，因为 wiring/wire_*.go 有 20 处调用方，
// 但判定一律下沉到 pkg/conf。

// APIInProcessEnabled reports whether legacy in-process app wiring remains enabled.
func APIInProcessEnabled() bool {
	return conf.Get().Moe.APIInProcess
}

// SingleProcessEnabled reports whether the repo standard single-process moe-social mode is on.
func SingleProcessEnabled() bool {
	return conf.Get().Moe.SingleProcess
}

func UserAPIInProcessEnabled() bool {
	return conf.DomainInProcess("user")
}

func VIPAPIInProcessEnabled() bool {
	return conf.DomainInProcess("vip")
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
