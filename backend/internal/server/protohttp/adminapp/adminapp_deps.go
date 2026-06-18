package adminapphttp

import (
	"backend/internal/platform/svc"
	aiapp "backend/internal/service/ai"
)

// Option 可选依赖（P1 legacy 路由：媒体库 / 运行时配置 / AI 代理审计）。
type Option func(*Server)

// WithServiceContext 注入 ServiceContext（媒体、运行时配置、审计）。
func WithServiceContext(svcCtx *svc.ServiceContext) Option {
	return func(s *Server) {
		s.svcCtx = svcCtx
	}
}

// WithAIApp 注入 AI 应用服务（酒馆角色卡更新）。
func WithAIApp(app *aiapp.AppService) Option {
	return func(s *Server) {
		s.ai = app
	}
}
