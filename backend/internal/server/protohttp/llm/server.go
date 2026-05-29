package llmhttp

import (
	"context"

	llmv1 "backend/api/llm/v1"
	userbiz "backend/internal/biz/user"
	llmapp "backend/internal/service/llm"
)

// Server 实现 llm.v1.LlmChat gRPC/HTTP（RecordLlmChatTurn + 用户记忆）。
type Server struct {
	llmv1.UnimplementedLlmChatServer
	app              *llmapp.AppService
	memoryGW         userbiz.LLMMemoryGateway
	inferenceBaseURL string
}

// New 构造 LlmChat gRPC/HTTP 服务。
func New(app *llmapp.AppService, opts ...Option) *Server {
	s := &Server{app: app}
	for _, o := range opts {
		o(s)
	}
	return s
}

// Option 可选依赖（混合记忆检索）。
type Option func(*Server)

// WithMemorySearch 注入混合检索网关与推理 base URL。
func WithMemorySearch(gw userbiz.LLMMemoryGateway, inferenceBaseURL string) Option {
	return func(s *Server) {
		s.memoryGW = gw
		s.inferenceBaseURL = inferenceBaseURL
	}
}

func (s *Server) requireApp() (*llmapp.AppService, error) {
	if s.app == nil {
		return nil, errLLMAppNil
	}
	return s.app, nil
}

func (s *Server) RecordLlmChatTurn(ctx context.Context, in *llmv1.RecordLlmChatTurnReq) (*llmv1.RecordLlmChatTurnResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.RecordLlmChatTurn(ctx, in)
}
