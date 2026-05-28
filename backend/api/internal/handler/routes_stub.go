//go:build !hybrid

package handler

// RegisterHandlers 生产默认空实现（P4-H）；Hybrid 回滚用 `-tags hybrid` 编译 routes.go。
func RegisterHandlers(server any, serverCtx any) {
	_ = server
	_ = serverCtx
}
