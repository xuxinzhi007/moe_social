// Package aiapp AI 资源域应用服务。
package aiapp

import (
	"context"

	aiv1 "backend/api/ai/v1"
	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"

	"gorm.io/gorm"
)

// AppService AI 资源应用层。
type AppService struct {
	store aibiz.AiStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: aidata.NewStore(db)}
}

func (s *AppService) ListAiProviders(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	out, err := aibiz.List(ctx, s.store, "providers", aiv1.ListAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.ListAiResourceRespFromMoe(out), nil
}

func (s *AppService) ListAiAgents(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	out, err := aibiz.List(ctx, s.store, "agents", aiv1.ListAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.ListAiResourceRespFromMoe(out), nil
}

func (s *AppService) ListAiLorebooks(ctx context.Context, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	out, err := aibiz.List(ctx, s.store, "lorebooks", aiv1.ListAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.ListAiResourceRespFromMoe(out), nil
}

func (s *AppService) ListPublicAiAgents(ctx context.Context, in *aiv1.ListPublicAiAgentsReq) (*aiv1.ListAiResourceResp, error) {
	out, err := aibiz.ListPublicAgents(ctx, s.store, aiv1.ListPublicAiAgentsReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.ListAiResourceRespFromMoe(out), nil
}

func (s *AppService) UpsertAiProvider(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "providers", aiv1.UpsertAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.UpsertAiResourceRespFromMoe(out.Resp), nil
}

func (s *AppService) UpsertAiAgent(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "agents", aiv1.UpsertAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.UpsertAiResourceRespFromMoe(out.Resp), nil
}

func (s *AppService) UpsertAiLorebook(ctx context.Context, in *aiv1.UpsertAiResourceReq) (*aiv1.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.store, "lorebooks", aiv1.UpsertAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.UpsertAiResourceRespFromMoe(out.Resp), nil
}

func (s *AppService) DeleteAiProvider(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "providers", aiv1.DeleteAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.DeleteAiResourceRespFromMoe(out.Resp), nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "agents", aiv1.DeleteAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.DeleteAiResourceRespFromMoe(out.Resp), nil
}

func (s *AppService) DeleteAiLorebook(ctx context.Context, in *aiv1.DeleteAiResourceReq) (*aiv1.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.store, "lorebooks", aiv1.DeleteAiResourceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return aiv1.DeleteAiResourceRespFromMoe(out.Resp), nil
}
