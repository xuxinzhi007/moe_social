package llmhttp

import (
	llmv1 "backend/api/llm/v1"
	llmapp "backend/internal/service/llm"
)

type Server struct {
	llmv1.UnimplementedLlmChatServer
	app *llmapp.AppService
}

func New(app *llmapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*llmapp.AppService, error) {
	if s.app == nil {
		return nil, errLLMAppNil
	}
	return s.app, nil
}
