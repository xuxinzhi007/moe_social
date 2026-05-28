package landinggw

import (
	"backend/api/internal/gwutil"
	"context"

	landingapp "backend/internal/service/landing"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Landing HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *landingapp.AppService
}

// New 构造网关。
func New(local *landingapp.AppService) *Gateway {
	return &Gateway{local: local}
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) SubmitLandingFeedback(ctx context.Context, in *moe.SubmitLandingFeedbackReq, opts ...grpc.CallOption) (*moe.SubmitLandingFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.Submit(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListLandingFeedback(ctx context.Context, in *moe.ListLandingFeedbackReq, opts ...grpc.CallOption) (*moe.ListLandingFeedbackResp, error) {
	if g != nil && g.local != nil {
		return g.local.List(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
