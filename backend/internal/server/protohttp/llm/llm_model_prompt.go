package llmhttp

import (
	"context"

	llmv1 "backend/api/llm/v1"
)

// GetLlmModelPrompt returns the server-normalized system prompt of an authorized model.
func (s *Server) GetLlmModelPrompt(ctx context.Context, in *llmv1.GetLlmModelPromptReq) (*llmv1.GetLlmModelPromptResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	prompt, err := app.ModelPrompt(ctx, in.GetModel())
	if err != nil {
		return nil, err
	}
	return &llmv1.GetLlmModelPromptResp{SystemPrompt: prompt}, nil
}
