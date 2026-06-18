package aiapp

import (
	"context"
	aiv1 "backend/api/ai/v1"
	aibiz "backend/internal/biz/ai"
)

func (s *AppService) UpsertAiProvider(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiAgent(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiLorebook(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiProvider(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiLorebook(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}
