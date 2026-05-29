package usergw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUsers(ctx context.Context, in *moe.GetUsersReq, opts ...grpc.CallOption) (*moe.GetUsersResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUsers(ctx, userv1.GetUsersReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUsersRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserCount(ctx context.Context, in *moe.GetUserCountReq, opts ...grpc.CallOption) (*moe.GetUserCountResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserCount(ctx, userv1.GetUserCountReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUserCountRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserByEmail(ctx context.Context, in *moe.GetUserByEmailReq, opts ...grpc.CallOption) (*moe.GetUserByEmailResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserByEmail(ctx, userv1.GetUserByEmailReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUserByEmailRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserInfo(ctx context.Context, in *moe.UpdateUserInfoReq, opts ...grpc.CallOption) (*moe.UpdateUserInfoResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateUserInfo(ctx, userv1.UpdateUserInfoReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.UpdateUserInfoRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserPassword(ctx context.Context, in *moe.UpdateUserPasswordReq, opts ...grpc.CallOption) (*moe.UpdateUserPasswordResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateUserPassword(ctx, userv1.UpdateUserPasswordReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.UpdateUserPasswordRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ResetPassword(ctx context.Context, in *moe.ResetPasswordReq, opts ...grpc.CallOption) (*moe.ResetPasswordResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ResetPassword(ctx, userv1.ResetPasswordReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ResetPasswordRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeleteUser(ctx context.Context, in *moe.DeleteUserReq, opts ...grpc.CallOption) (*moe.DeleteUserResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.DeleteUser(ctx, userv1.DeleteUserReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.DeleteUserRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateVipOrder(ctx context.Context, in *moe.CreateVipOrderReq, opts ...grpc.CallOption) (*moe.CreateVipOrderResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateVipOrder(ctx, vipv1.CreateVipOrderReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.CreateVipOrderRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserVip(ctx context.Context, in *moe.UpdateUserVipReq, opts ...grpc.CallOption) (*moe.UpdateUserVipResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateUserVip(ctx, vipv1.UpdateUserVipReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.UpdateUserVipRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SyncUserVipStatus(ctx context.Context, in *moe.SyncUserVipStatusReq, opts ...grpc.CallOption) (*moe.SyncUserVipStatusResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SyncUserVipStatus(ctx, vipv1.SyncUserVipStatusReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.SyncUserVipStatusRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateAutoRenew(ctx context.Context, in *moe.UpdateAutoRenewReq, opts ...grpc.CallOption) (*moe.UpdateAutoRenewResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateAutoRenew(ctx, vipv1.UpdateAutoRenewReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.UpdateAutoRenewRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetVipRecords(ctx context.Context, in *moe.GetVipRecordsReq, opts ...grpc.CallOption) (*moe.GetVipRecordsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetVipRecords(ctx, vipv1.GetVipRecordsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.GetVipRecordsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetUserActiveVipRecord(ctx context.Context, in *moe.GetUserActiveVipRecordReq, opts ...grpc.CallOption) (*moe.GetUserActiveVipRecordResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserActiveVipRecord(ctx, vipv1.GetUserActiveVipRecordReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return vipv1.GetUserActiveVipRecordRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetTransactions(ctx context.Context, in *moe.GetTransactionsReq, opts ...grpc.CallOption) (*moe.GetTransactionsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetTransactions(ctx, userv1.GetTransactionsReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetTransactionsRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetTransaction(ctx context.Context, in *moe.GetTransactionReq, opts ...grpc.CallOption) (*moe.GetTransactionResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetTransaction(ctx, userv1.GetTransactionReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetTransactionRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) Recharge(ctx context.Context, in *moe.RechargeReq, opts ...grpc.CallOption) (*moe.RechargeResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.Recharge(ctx, userv1.RechargeReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.RechargeRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) FeishuLogin(ctx context.Context, in *moe.FeishuLoginReq, opts ...grpc.CallOption) (*moe.FeishuLoginResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.FeishuLogin(ctx, userv1.FeishuLoginReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.FeishuLoginRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) FeishuAuthorizeURL(ctx context.Context, in *moe.FeishuAuthorizeURLReq, opts ...grpc.CallOption) (*moe.FeishuAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.FeishuAuthorizeURL(ctx, userv1.FeishuAuthorizeURLReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.FeishuAuthorizeURLRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) BindFeishu(ctx context.Context, in *moe.BindFeishuReq, opts ...grpc.CallOption) (*moe.BindFeishuResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.BindFeishu(ctx, userv1.BindFeishuReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.BindFeishuRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UnbindFeishu(ctx context.Context, in *moe.UnbindFeishuReq, opts ...grpc.CallOption) (*moe.UnbindFeishuResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UnbindFeishu(ctx, userv1.UnbindFeishuReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.UnbindFeishuRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SendFeishuTestCard(ctx context.Context, in *moe.SendFeishuTestCardReq, opts ...grpc.CallOption) (*moe.SendFeishuTestCardResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SendFeishuTestCard(ctx, userv1.SendFeishuTestCardReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.SendFeishuTestCardRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) WechatLogin(ctx context.Context, in *moe.WechatLoginReq, opts ...grpc.CallOption) (*moe.WechatLoginResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.WechatLogin(ctx, userv1.WechatLoginReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.WechatLoginRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) WechatAuthorizeURL(ctx context.Context, in *moe.WechatAuthorizeURLReq, opts ...grpc.CallOption) (*moe.WechatAuthorizeURLResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.WechatAuthorizeURL(ctx, userv1.WechatAuthorizeURLReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.WechatAuthorizeURLRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ListUserDevices(ctx context.Context, in *moe.ListUserDevicesReq, opts ...grpc.CallOption) (*moe.ListUserDevicesResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.ListUserDevices(ctx, userv1.ListUserDevicesReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.ListUserDevicesRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) SyncUserDevice(ctx context.Context, in *moe.SyncUserDeviceReq, opts ...grpc.CallOption) (*moe.SyncUserDeviceResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.SyncUserDevice(ctx, userv1.SyncUserDeviceReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.SyncUserDeviceRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
