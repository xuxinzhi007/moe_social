package handler

// RegisterHandlers 生产空实现；HTTP 由 http_proto + httplegacy 注册。
func RegisterHandlers(server any, serverCtx any) {
	_ = server
	_ = serverCtx
}
