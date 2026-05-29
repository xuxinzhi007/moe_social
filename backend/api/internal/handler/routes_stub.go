//go:build !hybrid

package handler

// RegisterHandlers 生产默认空实现；HTTP 由 api/moehttp 注册。
func RegisterHandlers(server any, serverCtx any) {
	_ = server
	_ = serverCtx
}
