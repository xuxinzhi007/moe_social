package landinggw

import (
	"context"

	landingapp "backend/internal/service/landing"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway Landing HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *landingapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *landingapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由模式。
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

func (g *Gateway) SubmitLandingFeedback(ctx context.Context, in *super.SubmitLandingFeedbackReq, opts ...grpc.CallOption) (*super.SubmitLandingFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.Submit(ctx, in)
	}
	return g.super.SubmitLandingFeedback(ctx, in, opts...)
}

func (g *Gateway) ListLandingFeedback(ctx context.Context, in *super.ListLandingFeedbackReq, opts ...grpc.CallOption) (*super.ListLandingFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.List(ctx, in)
	}
	return g.super.ListLandingFeedback(ctx, in, opts...)
}
