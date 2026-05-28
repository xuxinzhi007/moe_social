package usergw

import (
	"backend/api/internal/gwutil"
	"context"

	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUsers(ctx context.Context, in *moe.GetUsersReq, opts ...grpc.CallOption) (*moe.GetUsersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUsers(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserCount(ctx context.Context, in *moe.GetUserCountReq, opts ...grpc.CallOption) (*moe.GetUserCountResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserCount(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserByEmail(ctx context.Context, in *moe.GetUserByEmailReq, opts ...grpc.CallOption) (*moe.GetUserByEmailResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserByEmail(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserInfo(ctx context.Context, in *moe.UpdateUserInfoReq, opts ...grpc.CallOption) (*moe.UpdateUserInfoResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserInfo(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserPassword(ctx context.Context, in *moe.UpdateUserPasswordReq, opts ...grpc.CallOption) (*moe.UpdateUserPasswordResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserPassword(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ResetPassword(ctx context.Context, in *moe.ResetPasswordReq, opts ...grpc.CallOption) (*moe.ResetPasswordResp, error) {
	if g != nil && g.local != nil {
		return g.local.ResetPassword(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteUser(ctx context.Context, in *moe.DeleteUserReq, opts ...grpc.CallOption) (*moe.DeleteUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteUser(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateVipOrder(ctx context.Context, in *moe.CreateVipOrderReq, opts ...grpc.CallOption) (*moe.CreateVipOrderResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateVipOrder(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserVip(ctx context.Context, in *moe.UpdateUserVipReq, opts ...grpc.CallOption) (*moe.UpdateUserVipResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserVip(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SyncUserVipStatus(ctx context.Context, in *moe.SyncUserVipStatusReq, opts ...grpc.CallOption) (*moe.SyncUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.SyncUserVipStatus(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateAutoRenew(ctx context.Context, in *moe.UpdateAutoRenewReq, opts ...grpc.CallOption) (*moe.UpdateAutoRenewResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAutoRenew(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetVipRecords(ctx context.Context, in *moe.GetVipRecordsReq, opts ...grpc.CallOption) (*moe.GetVipRecordsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetVipRecords(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserActiveVipRecord(ctx context.Context, in *moe.GetUserActiveVipRecordReq, opts ...grpc.CallOption) (*moe.GetUserActiveVipRecordResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserActiveVipRecord(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetTransactions(ctx context.Context, in *moe.GetTransactionsReq, opts ...grpc.CallOption) (*moe.GetTransactionsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetTransactions(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetTransaction(ctx context.Context, in *moe.GetTransactionReq, opts ...grpc.CallOption) (*moe.GetTransactionResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetTransaction(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) Recharge(ctx context.Context, in *moe.RechargeReq, opts ...grpc.CallOption) (*moe.RechargeResp, error) {
	if g != nil && g.local != nil {
		return g.local.Recharge(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) FeishuLogin(ctx context.Context, in *moe.FeishuLoginReq, opts ...grpc.CallOption) (*moe.FeishuLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.FeishuLogin(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) FeishuAuthorizeURL(ctx context.Context, in *moe.FeishuAuthorizeURLReq, opts ...grpc.CallOption) (*moe.FeishuAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		return g.local.FeishuAuthorizeURL(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) BindFeishu(ctx context.Context, in *moe.BindFeishuReq, opts ...grpc.CallOption) (*moe.BindFeishuResp, error) {
	if g != nil && g.local != nil {
		return g.local.BindFeishu(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UnbindFeishu(ctx context.Context, in *moe.UnbindFeishuReq, opts ...grpc.CallOption) (*moe.UnbindFeishuResp, error) {
	if g != nil && g.local != nil {
		return g.local.UnbindFeishu(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SendFeishuTestCard(ctx context.Context, in *moe.SendFeishuTestCardReq, opts ...grpc.CallOption) (*moe.SendFeishuTestCardResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendFeishuTestCard(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) WechatLogin(ctx context.Context, in *moe.WechatLoginReq, opts ...grpc.CallOption) (*moe.WechatLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.WechatLogin(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) WechatAuthorizeURL(ctx context.Context, in *moe.WechatAuthorizeURLReq, opts ...grpc.CallOption) (*moe.WechatAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		return g.local.WechatAuthorizeURL(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListUserDevices(ctx context.Context, in *moe.ListUserDevicesReq, opts ...grpc.CallOption) (*moe.ListUserDevicesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserDevices(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SyncUserDevice(ctx context.Context, in *moe.SyncUserDeviceReq, opts ...grpc.CallOption) (*moe.SyncUserDeviceResp, error) {
	if g != nil && g.local != nil {
		return g.local.SyncUserDevice(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
