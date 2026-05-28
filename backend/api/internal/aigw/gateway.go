package aigw

import (
	"backend/api/internal/gwutil"
	"context"

	aiv1 "backend/api/ai/v1"
	aiapp "backend/internal/service/ai"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway AI HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *aiapp.AppService
}

// New 构造网关。
func New(local *aiapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) ListAiProviders(ctx context.Context, in *moe.ListAiResourceReq, opts ...grpc.CallOption) (*moe.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAiProviders(ctx, aiv1.ListAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.ListAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpsertAiProvider(ctx context.Context, in *moe.UpsertAiResourceReq, opts ...grpc.CallOption) (*moe.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertAiProvider(ctx, aiv1.UpsertAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.UpsertAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteAiProvider(ctx context.Context, in *moe.DeleteAiResourceReq, opts ...grpc.CallOption) (*moe.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAiProvider(ctx, aiv1.DeleteAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.DeleteAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListAiAgents(ctx context.Context, in *moe.ListAiResourceReq, opts ...grpc.CallOption) (*moe.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAiAgents(ctx, aiv1.ListAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.ListAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListPublicAiAgents(ctx context.Context, in *moe.ListPublicAiAgentsReq, opts ...grpc.CallOption) (*moe.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListPublicAiAgents(ctx, aiv1.ListPublicAiAgentsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.ListAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpsertAiAgent(ctx context.Context, in *moe.UpsertAiResourceReq, opts ...grpc.CallOption) (*moe.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertAiAgent(ctx, aiv1.UpsertAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.UpsertAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteAiAgent(ctx context.Context, in *moe.DeleteAiResourceReq, opts ...grpc.CallOption) (*moe.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAiAgent(ctx, aiv1.DeleteAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.DeleteAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListAiLorebooks(ctx context.Context, in *moe.ListAiResourceReq, opts ...grpc.CallOption) (*moe.ListAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListAiLorebooks(ctx, aiv1.ListAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.ListAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpsertAiLorebook(ctx context.Context, in *moe.UpsertAiResourceReq, opts ...grpc.CallOption) (*moe.UpsertAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpsertAiLorebook(ctx, aiv1.UpsertAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.UpsertAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteAiLorebook(ctx context.Context, in *moe.DeleteAiResourceReq, opts ...grpc.CallOption) (*moe.DeleteAiResourceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteAiLorebook(ctx, aiv1.DeleteAiResourceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return aiv1.DeleteAiResourceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
