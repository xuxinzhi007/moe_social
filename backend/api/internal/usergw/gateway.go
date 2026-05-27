package usergw

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway User HTTP→biz 或 super RPC 回退。
type Gateway struct {
	local *userapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *userapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由。
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

func (g *Gateway) Login(ctx context.Context, in *super.LoginReq, opts ...grpc.CallOption) (*super.LoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.Login(ctx, in)
	}
	return g.super.Login(ctx, in, opts...)
}

func (g *Gateway) Register(ctx context.Context, in *super.RegisterReq, opts ...grpc.CallOption) (*super.RegisterResp, error) {
	if g != nil && g.local != nil {
		return g.local.Register(ctx, in)
	}
	return g.super.Register(ctx, in, opts...)
}

func (g *Gateway) GetUserInfo(ctx context.Context, in *super.GetUserInfoReq, opts ...grpc.CallOption) (*super.GetUserInfoResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserInfo(ctx, in)
	}
	return g.super.GetUserInfo(ctx, in, opts...)
}

func (g *Gateway) GetUser(ctx context.Context, in *super.GetUserReq, opts ...grpc.CallOption) (*super.GetUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUser(ctx, in)
	}
	return g.super.GetUser(ctx, in, opts...)
}

func (g *Gateway) GetUserVipStatus(ctx context.Context, in *super.GetUserVipStatusReq, opts ...grpc.CallOption) (*super.GetUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserVipStatus(ctx, in)
	}
	return g.super.GetUserVipStatus(ctx, in, opts...)
}

func (g *Gateway) CheckUserVip(ctx context.Context, in *super.CheckUserVipReq, opts ...grpc.CallOption) (*super.CheckUserVipResp, error) {
	if g != nil && g.local != nil {
		return g.local.CheckUserVip(ctx, in)
	}
	return g.super.CheckUserVip(ctx, in, opts...)
}

// Super 未迁移方法仍走 RPC。
func (g *Gateway) Super() super.SuperClient {
	if g == nil {
		return nil
	}
	return g.super
}
