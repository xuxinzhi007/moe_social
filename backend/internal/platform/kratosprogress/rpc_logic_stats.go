package kratosprogress

import "backend/internal/platform/moewiring"

// RPCLegacyLogicBaseline 历史 Super goctl logic 文件数（rpc/ 已删除）。
const RPCLegacyLogicBaseline = 209

// RPCLegacyLogicFileCount 已退役；rpc/internal/logic 不再存在。
func RPCLegacyLogicFileCount() int {
	return 0
}

// RPCLegacyLogicRetiredPercent Super logic 清库进度（0～100）。
func RPCLegacyLogicRetiredPercent() int {
	return 100
}

// P5SuperRuntimePercent P5-A：Super 运行时退役（不注册 gRPC、API 不走 zrpc 回环）。
func P5SuperRuntimePercent() int {
	return boolPercent(moewiring.SuperGrpcRetired())
}
