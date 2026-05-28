package admingw

import (
	"backend/api/internal/gwutil"
	"context"

	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) AdminLogin(ctx context.Context, in *moe.AdminLoginReq, opts ...grpc.CallOption) (*moe.AdminLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminLogin(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapAccount(ctx context.Context, in *moe.AdminBootstrapAccountReq, opts ...grpc.CallOption) (*moe.AdminBootstrapAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapAccount(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
