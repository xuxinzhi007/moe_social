package companionhttp

import (
	"testing"

	companionv1 "backend/api/companion/v1"
	"backend/internal/server/protohttp/prototest"
)

// Companion 的每个 RPC 都必须有 HTTP 适配方法。
// ConfirmMemory / ListProactiveDeliveries / RevokeProactiveDelivery 三个曾经漏写：
// AppService 侧实现完整、Flutter 侧照常调用，但请求落回嵌入桩，线上永远 501。
func TestEveryCompanionRPCIsAdapted(t *testing.T) {
	// GetContextPreview 无路由调用方，已判定为死接口待删（批次 #42）。
	prototest.AssertRPCsAdapted(t, &Server{}, companionv1.UnimplementedCompanionServer{},
		errCompanionAppNil, "GetContextPreview")
}
