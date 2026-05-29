package admingw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	adminv1 "backend/api/admin/v1"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) AdminLogin(ctx context.Context, in *moe.AdminLoginReq, opts ...grpc.CallOption) (*moe.AdminLoginResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminLogin(ctx, adminv1.AdminLoginReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminLoginRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) AdminBootstrapAccount(ctx context.Context, in *moe.AdminBootstrapAccountReq, opts ...grpc.CallOption) (*moe.AdminBootstrapAccountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.AdminBootstrapAccount(ctx, adminv1.AdminBootstrapAccountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.AdminBootstrapAccountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
