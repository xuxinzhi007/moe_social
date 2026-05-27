package aigw

import (
	"context"

	aiapp "backend/internal/service/ai"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway AI HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *aiapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *aiapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) ListAiProviders(ctx context.Context, in *super.ListAiResourceReq, opts ...grpc.CallOption) (*super.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiProviders(ctx, in)
	}
	return g.super.ListAiProviders(ctx, in, opts...)
}

func (g *Gateway) UpsertAiProvider(ctx context.Context, in *super.UpsertAiResourceReq, opts ...grpc.CallOption) (*super.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertAiProvider(ctx, in)
	}
	return g.super.UpsertAiProvider(ctx, in, opts...)
}

func (g *Gateway) DeleteAiProvider(ctx context.Context, in *super.DeleteAiResourceReq, opts ...grpc.CallOption) (*super.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAiProvider(ctx, in)
	}
	return g.super.DeleteAiProvider(ctx, in, opts...)
}

func (g *Gateway) ListAiAgents(ctx context.Context, in *super.ListAiResourceReq, opts ...grpc.CallOption) (*super.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiAgents(ctx, in)
	}
	return g.super.ListAiAgents(ctx, in, opts...)
}

func (g *Gateway) ListPublicAiAgents(ctx context.Context, in *super.ListPublicAiAgentsReq, opts ...grpc.CallOption) (*super.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPublicAiAgents(ctx, in)
	}
	return g.super.ListPublicAiAgents(ctx, in, opts...)
}

func (g *Gateway) UpsertAiAgent(ctx context.Context, in *super.UpsertAiResourceReq, opts ...grpc.CallOption) (*super.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertAiAgent(ctx, in)
	}
	return g.super.UpsertAiAgent(ctx, in, opts...)
}

func (g *Gateway) DeleteAiAgent(ctx context.Context, in *super.DeleteAiResourceReq, opts ...grpc.CallOption) (*super.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAiAgent(ctx, in)
	}
	return g.super.DeleteAiAgent(ctx, in, opts...)
}

func (g *Gateway) ListAiLorebooks(ctx context.Context, in *super.ListAiResourceReq, opts ...grpc.CallOption) (*super.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiLorebooks(ctx, in)
	}
	return g.super.ListAiLorebooks(ctx, in, opts...)
}

func (g *Gateway) UpsertAiLorebook(ctx context.Context, in *super.UpsertAiResourceReq, opts ...grpc.CallOption) (*super.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertAiLorebook(ctx, in)
	}
	return g.super.UpsertAiLorebook(ctx, in, opts...)
}

func (g *Gateway) DeleteAiLorebook(ctx context.Context, in *super.DeleteAiResourceReq, opts ...grpc.CallOption) (*super.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAiLorebook(ctx, in)
	}
	return g.super.DeleteAiLorebook(ctx, in, opts...)
}
