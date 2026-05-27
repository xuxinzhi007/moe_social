package usergw

import (
	"context"

	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUsers(ctx context.Context, in *super.GetUsersReq, opts ...grpc.CallOption) (*super.GetUsersResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUsers(ctx, in)
	}
	return g.super.GetUsers(ctx, in, opts...)
}

func (g *Gateway) GetUserCount(ctx context.Context, in *super.GetUserCountReq, opts ...grpc.CallOption) (*super.GetUserCountResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserCount(ctx, in)
	}
	return g.super.GetUserCount(ctx, in, opts...)
}

func (g *Gateway) GetUserByEmail(ctx context.Context, in *super.GetUserByEmailReq, opts ...grpc.CallOption) (*super.GetUserByEmailResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserByEmail(ctx, in)
	}
	return g.super.GetUserByEmail(ctx, in, opts...)
}

func (g *Gateway) UpdateUserInfo(ctx context.Context, in *super.UpdateUserInfoReq, opts ...grpc.CallOption) (*super.UpdateUserInfoResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserInfo(ctx, in)
	}
	return g.super.UpdateUserInfo(ctx, in, opts...)
}

func (g *Gateway) UpdateUserPassword(ctx context.Context, in *super.UpdateUserPasswordReq, opts ...grpc.CallOption) (*super.UpdateUserPasswordResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserPassword(ctx, in)
	}
	return g.super.UpdateUserPassword(ctx, in, opts...)
}

func (g *Gateway) ResetPassword(ctx context.Context, in *super.ResetPasswordReq, opts ...grpc.CallOption) (*super.ResetPasswordResp, error) {
	if g != nil && g.local != nil {
		return g.local.ResetPassword(ctx, in)
	}
	return g.super.ResetPassword(ctx, in, opts...)
}

func (g *Gateway) DeleteUser(ctx context.Context, in *super.DeleteUserReq, opts ...grpc.CallOption) (*super.DeleteUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteUser(ctx, in)
	}
	return g.super.DeleteUser(ctx, in, opts...)
}

func (g *Gateway) CreateVipOrder(ctx context.Context, in *super.CreateVipOrderReq, opts ...grpc.CallOption) (*super.CreateVipOrderResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateVipOrder(ctx, in)
	}
	return g.super.CreateVipOrder(ctx, in, opts...)
}

func (g *Gateway) UpdateUserVip(ctx context.Context, in *super.UpdateUserVipReq, opts ...grpc.CallOption) (*super.UpdateUserVipResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserVip(ctx, in)
	}
	return g.super.UpdateUserVip(ctx, in, opts...)
}

func (g *Gateway) SyncUserVipStatus(ctx context.Context, in *super.SyncUserVipStatusReq, opts ...grpc.CallOption) (*super.SyncUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		return g.local.SyncUserVipStatus(ctx, in)
	}
	return g.super.SyncUserVipStatus(ctx, in, opts...)
}

func (g *Gateway) UpdateAutoRenew(ctx context.Context, in *super.UpdateAutoRenewReq, opts ...grpc.CallOption) (*super.UpdateAutoRenewResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAutoRenew(ctx, in)
	}
	return g.super.UpdateAutoRenew(ctx, in, opts...)
}

func (g *Gateway) GetVipRecords(ctx context.Context, in *super.GetVipRecordsReq, opts ...grpc.CallOption) (*super.GetVipRecordsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetVipRecords(ctx, in)
	}
	return g.super.GetVipRecords(ctx, in, opts...)
}

func (g *Gateway) GetUserActiveVipRecord(ctx context.Context, in *super.GetUserActiveVipRecordReq, opts ...grpc.CallOption) (*super.GetUserActiveVipRecordResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserActiveVipRecord(ctx, in)
	}
	return g.super.GetUserActiveVipRecord(ctx, in, opts...)
}

func (g *Gateway) GetTransactions(ctx context.Context, in *super.GetTransactionsReq, opts ...grpc.CallOption) (*super.GetTransactionsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetTransactions(ctx, in)
	}
	return g.super.GetTransactions(ctx, in, opts...)
}

func (g *Gateway) GetTransaction(ctx context.Context, in *super.GetTransactionReq, opts ...grpc.CallOption) (*super.GetTransactionResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetTransaction(ctx, in)
	}
	return g.super.GetTransaction(ctx, in, opts...)
}

func (g *Gateway) Recharge(ctx context.Context, in *super.RechargeReq, opts ...grpc.CallOption) (*super.RechargeResp, error) {
	if g != nil && g.local != nil {
		return g.local.Recharge(ctx, in)
	}
	return g.super.Recharge(ctx, in, opts...)
}

func (g *Gateway) FeishuLogin(ctx context.Context, in *super.FeishuLoginReq, opts ...grpc.CallOption) (*super.FeishuLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.FeishuLogin(ctx, in)
	}
	return g.super.FeishuLogin(ctx, in, opts...)
}

func (g *Gateway) FeishuAuthorizeURL(ctx context.Context, in *super.FeishuAuthorizeURLReq, opts ...grpc.CallOption) (*super.FeishuAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		return g.local.FeishuAuthorizeURL(ctx, in)
	}
	return g.super.FeishuAuthorizeURL(ctx, in, opts...)
}

func (g *Gateway) BindFeishu(ctx context.Context, in *super.BindFeishuReq, opts ...grpc.CallOption) (*super.BindFeishuResp, error) {
	if g != nil && g.local != nil {
		return g.local.BindFeishu(ctx, in)
	}
	return g.super.BindFeishu(ctx, in, opts...)
}

func (g *Gateway) UnbindFeishu(ctx context.Context, in *super.UnbindFeishuReq, opts ...grpc.CallOption) (*super.UnbindFeishuResp, error) {
	if g != nil && g.local != nil {
		return g.local.UnbindFeishu(ctx, in)
	}
	return g.super.UnbindFeishu(ctx, in, opts...)
}

func (g *Gateway) SendFeishuTestCard(ctx context.Context, in *super.SendFeishuTestCardReq, opts ...grpc.CallOption) (*super.SendFeishuTestCardResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendFeishuTestCard(ctx, in)
	}
	return g.super.SendFeishuTestCard(ctx, in, opts...)
}

func (g *Gateway) WechatLogin(ctx context.Context, in *super.WechatLoginReq, opts ...grpc.CallOption) (*super.WechatLoginResp, error) {
	if g != nil && g.local != nil {
		return g.local.WechatLogin(ctx, in)
	}
	return g.super.WechatLogin(ctx, in, opts...)
}

func (g *Gateway) WechatAuthorizeURL(ctx context.Context, in *super.WechatAuthorizeURLReq, opts ...grpc.CallOption) (*super.WechatAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		return g.local.WechatAuthorizeURL(ctx, in)
	}
	return g.super.WechatAuthorizeURL(ctx, in, opts...)
}

func (g *Gateway) ListUserDevices(ctx context.Context, in *super.ListUserDevicesReq, opts ...grpc.CallOption) (*super.ListUserDevicesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUserDevices(ctx, in)
	}
	return g.super.ListUserDevices(ctx, in, opts...)
}

func (g *Gateway) SyncUserDevice(ctx context.Context, in *super.SyncUserDeviceReq, opts ...grpc.CallOption) (*super.SyncUserDeviceResp, error) {
	if g != nil && g.local != nil {
		return g.local.SyncUserDevice(ctx, in)
	}
	return g.super.SyncUserDevice(ctx, in, opts...)
}
