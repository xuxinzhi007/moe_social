package admingw

import (
	"context"

	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) AdminLogin(ctx context.Context, in *moe.AdminLoginReq, opts ...grpc.CallOption) (*moe.AdminLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminLogin(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.AdminLogin(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapAccount(ctx context.Context, in *moe.AdminBootstrapAccountReq, opts ...grpc.CallOption) (*moe.AdminBootstrapAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapAccount(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.AdminBootstrapAccount(ctx, in, opts...)
}
