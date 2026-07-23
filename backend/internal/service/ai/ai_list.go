package aiapp

import (
	aiv1 "backend/api/ai/v1"
	"context"
)

func (s *AppService) ListAiProviders(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return s.resources.List(ctx, "providers", in)
}

func (s *AppService) ListAiAgents(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return s.resources.List(ctx, "agents", in)
}

func (s *AppService) ListAiLorebooks(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	return s.resources.List(ctx, "lorebooks", in)
}

func (s *AppService) ListPublicAiAgents(ctx context.Context, in *aiv1.ListPublicAiAgentsReq) (*aiv1.ListAiResourceResp, error) {
	return s.resources.ListPublicAgents(ctx, in)
}
