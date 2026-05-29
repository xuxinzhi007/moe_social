package httplegacy

import (
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserMemoryCompatRoutes P1：用户记忆已迁入 RegisterLlmChatHTTPServer。
const PilotNativeUserMemoryCompatRoutes = 0

// RegisterUserMemoryCompat P1 no-op（记忆路由已由 proto HTTP 承接）。
func RegisterUserMemoryCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	_ = srv
	_ = svcCtx
}
