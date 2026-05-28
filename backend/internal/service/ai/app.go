// Package aiapp AI 资源域应用服务。
package aiapp

import (
	"context"

	aibiz "backend/internal/biz/ai"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// AppService AI 资源应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

func (s *AppService) ListAiProviders(ctx context.Context, in *moe.ListAiResourceReq) (*moe.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.db, "providers", in)
}

func (s *AppService) ListAiAgents(ctx context.Context, in *moe.ListAiResourceReq) (*moe.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.db, "agents", in)
}

func (s *AppService) ListAiLorebooks(ctx context.Context, in *moe.ListAiResourceReq) (*moe.ListAiResourceResp, error) {
	return aibiz.List(ctx, s.db, "lorebooks", in)
}

func (s *AppService) ListPublicAiAgents(ctx context.Context, in *moe.ListPublicAiAgentsReq) (*moe.ListAiResourceResp, error) {
	return aibiz.ListPublicAgents(ctx, s.db, in)
}

func (s *AppService) UpsertAiProvider(ctx context.Context, in *moe.UpsertAiResourceReq) (*moe.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.db, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiAgent(ctx context.Context, in *moe.UpsertAiResourceReq) (*moe.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.db, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) UpsertAiLorebook(ctx context.Context, in *moe.UpsertAiResourceReq) (*moe.UpsertAiResourceResp, error) {
	out, err := aibiz.Upsert(ctx, s.db, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiProvider(ctx context.Context, in *moe.DeleteAiResourceReq) (*moe.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.db, "providers", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *moe.DeleteAiResourceReq) (*moe.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.db, "agents", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}

func (s *AppService) DeleteAiLorebook(ctx context.Context, in *moe.DeleteAiResourceReq) (*moe.DeleteAiResourceResp, error) {
	out, err := aibiz.Delete(ctx, s.db, "lorebooks", in)
	if err != nil {
		return nil, err
	}
	return out.Resp, nil
}
