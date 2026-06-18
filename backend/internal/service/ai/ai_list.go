package aiapp

import (
	"context"
	aiv1 "backend/api/ai/v1"
	aibiz "backend/internal/biz/ai"
)

func (s *AppService) ListAiProviders(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.store, "providers", in)
}

func (s *AppService) ListAiAgents(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.store, "agents", in)
}

func (s *AppService) ListAiLorebooks(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.store, "lorebooks", in)
}

func (s *AppService) ListPublicAiAgents(ctx context.Context, in *aiv1.ListPublicAiAgentsReq) (*aiv1.ListAiResourceResp, error) {
	return aibiz.ListPublicAgents(ctx, s.store, in)
}
