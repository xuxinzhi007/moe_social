package llmgrpc

import (
	"context"

	llmv1 "backend/api/llm/v1"
	llmapp "backend/internal/service/llm"
)

// Server 实现 llm.v1.LlmChat gRPC/HTTP（RecordLlmChatTurn）。
type Server struct {
	llmv1.UnimplementedLlmChatServer
	app *llmapp.AppService
}

// New 构造 LlmChat gRPC/HTTP 服务。
func New(app *llmapp.AppService) *Server {
	return &Server{app: app}
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
