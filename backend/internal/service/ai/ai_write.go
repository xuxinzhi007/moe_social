package aiapp

import (
	aiv1 "backend/api/ai/v1"
	"context"
)

func (s *AppService) UpsertAiProvider(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := s.resources.Upsert(ctx, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiAgent(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := s.resources.Upsert(ctx, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiLorebook(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := s.resources.Upsert(ctx, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiProvider(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := s.resources.Delete(ctx, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := s.resources.Delete(ctx, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiLorebook(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := s.resources.Delete(ctx, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}
