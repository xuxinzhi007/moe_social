package bootstrap

import (
	"backend/rpc/internal/logic"
	"backend/rpc/internal/svc"
)

// WireMoeAdmin 为 Kratos 混合层注入 RPC 依赖工厂。
func WireMoeAdmin(svc *svc.ServiceContext) {
	logic.AttachMoeAdminHooks(svc)
}
