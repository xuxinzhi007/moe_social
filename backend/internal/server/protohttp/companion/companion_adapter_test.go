package companionhttp

import (
	"testing"

	companionv1 "backend/api/companion/v1"
	"backend/internal/server/protohttp/prototest"
)

// Companion 的每个 RPC 都必须有 HTTP 适配方法。
// ConfirmMemory / ListProactiveDeliveries / RevokeProactiveDelivery 三个曾经漏写：
// AppService 侧实现完整、Flutter 侧照常调用，但请求落回嵌入桩，线上永远 501。
//
// GetContextPreview 曾挂在待删白名单里，已于 #42 从 proto 删除（无适配方法、
// Flutter 侧那个 getContextPreview 也零调用方），所以这里不再有豁免项。
func TestEveryCompanionRPCIsAdapted(t *testing.T) {
	prototest.AssertRPCsAdapted(t, &Server{}, companionv1.UnimplementedCompanionServer{},
		errCompanionAppNil)
}
