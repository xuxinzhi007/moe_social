package admingw

import (
	"context"

	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

func (g *Gateway) AdminLogin(ctx context.Context, in *super.AdminLoginReq, opts ...grpc.CallOption) (*super.AdminLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminLogin(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.AdminLogin(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapAccount(ctx context.Context, in *super.AdminBootstrapAccountReq, opts ...grpc.CallOption) (*super.AdminBootstrapAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapAccount(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.AdminBootstrapAccount(ctx, in, opts...)
}
