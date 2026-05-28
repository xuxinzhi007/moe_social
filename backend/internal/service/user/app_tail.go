// Package userapp F109 user tail RPC → biz wrappers.
package userapp

import (
	"context"

	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
)

func (s *AppService) GetUsers(ctx context.Context, in *userv1.GetUsersReq) (*userv1.GetUsersResp, error) {
	out, err := userbiz.GetUsers(ctx, s.store, userv1.GetUsersReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetUsersRespFromMoe(out), nil
}

func (s *AppService) GetUserCount(ctx context.Context, in *userv1.GetUserCountReq) (*userv1.GetUserCountResp, error) {
	out, err := userbiz.GetUserCount(ctx, s.store, userv1.GetUserCountReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetUserCountRespFromMoe(out), nil
}

func (s *AppService) GetUserByEmail(ctx context.Context, in *userv1.GetUserByEmailReq) (*userv1.GetUserByEmailResp, error) {
	out, err := userbiz.GetUserByEmail(ctx, s.store, userv1.GetUserByEmailReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetUserByEmailRespFromMoe(out), nil
}

func (s *AppService) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	out, err := userbiz.UpdateUserInfo(ctx, s.store, userv1.UpdateUserInfoReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.UpdateUserInfoRespFromMoe(out), nil
}

func (s *AppService) UpdateUserPassword(ctx context.Context, in *userv1.UpdateUserPasswordReq) (*userv1.UpdateUserPasswordResp, error) {
	out, err := userbiz.UpdateUserPassword(ctx, s.store, userv1.UpdateUserPasswordReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.UpdateUserPasswordRespFromMoe(out), nil
}

func (s *AppService) ResetPassword(ctx context.Context, in *userv1.ResetPasswordReq) (*userv1.ResetPasswordResp, error) {
	out, err := userbiz.ResetPassword(ctx, s.store, userv1.ResetPasswordReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.ResetPasswordRespFromMoe(out), nil
}

func (s *AppService) DeleteUser(ctx context.Context, in *userv1.DeleteUserReq) (*userv1.DeleteUserResp, error) {
	out, err := userbiz.DeleteUser(ctx, s.store, userv1.DeleteUserReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.DeleteUserRespFromMoe(out), nil
}

func (s *AppService) CreateVipOrder(ctx context.Context, in *vipv1.CreateVipOrderReq) (*vipv1.CreateVipOrderResp, error) {
	out, err := userbiz.CreateVipOrder(ctx, s.store, vipv1.CreateVipOrderReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.CreateVipOrderRespFromMoe(out), nil
}

func (s *AppService) UpdateUserVip(ctx context.Context, in *vipv1.UpdateUserVipReq) (*vipv1.UpdateUserVipResp, error) {
	out, err := userbiz.UpdateUserVip(ctx, s.store, vipv1.UpdateUserVipReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.UpdateUserVipRespFromMoe(out), nil
}

func (s *AppService) SyncUserVipStatus(ctx context.Context, in *vipv1.SyncUserVipStatusReq) (*vipv1.SyncUserVipStatusResp, error) {
	out, err := userbiz.SyncUserVipStatus(ctx, s.store, vipv1.SyncUserVipStatusReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.SyncUserVipStatusRespFromMoe(out), nil
}

func (s *AppService) UpdateAutoRenew(ctx context.Context, in *vipv1.UpdateAutoRenewReq) (*vipv1.UpdateAutoRenewResp, error) {
	out, err := userbiz.UpdateAutoRenew(ctx, s.store, vipv1.UpdateAutoRenewReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.UpdateAutoRenewRespFromMoe(out), nil
}

func (s *AppService) GetVipRecords(ctx context.Context, in *vipv1.GetVipRecordsReq) (*vipv1.GetVipRecordsResp, error) {
	out, err := userbiz.GetVipRecords(ctx, s.store, vipv1.GetVipRecordsReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.GetVipRecordsRespFromMoe(out), nil
}

func (s *AppService) GetUserActiveVipRecord(ctx context.Context, in *vipv1.GetUserActiveVipRecordReq) (*vipv1.GetUserActiveVipRecordResp, error) {
	out, err := userbiz.GetUserActiveVipRecord(ctx, s.store, vipv1.GetUserActiveVipRecordReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return vipv1.GetUserActiveVipRecordRespFromMoe(out), nil
}

func (s *AppService) GetTransactions(ctx context.Context, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	out, err := userbiz.GetTransactions(ctx, s.store, userv1.GetTransactionsReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetTransactionsRespFromMoe(out), nil
}

func (s *AppService) GetTransaction(ctx context.Context, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	out, err := userbiz.GetTransaction(ctx, s.store, userv1.GetTransactionReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetTransactionRespFromMoe(out), nil
}

func (s *AppService) Recharge(ctx context.Context, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	out, err := userbiz.Recharge(ctx, s.store, userv1.RechargeReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.RechargeRespFromMoe(out), nil
}

func (s *AppService) FeishuLogin(ctx context.Context, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	out, err := userbiz.FeishuLogin(ctx, s.store, userv1.FeishuLoginReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.FeishuLoginRespFromMoe(out), nil
}

func (s *AppService) FeishuAuthorizeURL(ctx context.Context, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	out, err := userbiz.FeishuAuthorizeURL(ctx, userv1.FeishuAuthorizeURLReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.FeishuAuthorizeURLRespFromMoe(out), nil
}

func (s *AppService) BindFeishu(ctx context.Context, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	out, err := userbiz.BindFeishu(ctx, s.store, userv1.BindFeishuReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.BindFeishuRespFromMoe(out), nil
}

func (s *AppService) UnbindFeishu(ctx context.Context, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	out, err := userbiz.UnbindFeishu(ctx, s.store, userv1.UnbindFeishuReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.UnbindFeishuRespFromMoe(out), nil
}

func (s *AppService) SendFeishuTestCard(ctx context.Context, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	out, err := userbiz.SendFeishuTestCard(ctx, s.store, userv1.SendFeishuTestCardReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.SendFeishuTestCardRespFromMoe(out), nil
}

func (s *AppService) WechatLogin(ctx context.Context, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	out, err := userbiz.WechatLogin(ctx, s.store, userv1.WechatLoginReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.WechatLoginRespFromMoe(out), nil
}

func (s *AppService) WechatAuthorizeURL(ctx context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	out, err := userbiz.WechatAuthorizeURL(ctx, userv1.WechatAuthorizeURLReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.WechatAuthorizeURLRespFromMoe(out), nil
}

func (s *AppService) ListUserDevices(ctx context.Context, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	out, err := userbiz.ListUserDevices(ctx, s.store, userv1.ListUserDevicesReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.ListUserDevicesRespFromMoe(out), nil
}

func (s *AppService) SyncUserDevice(ctx context.Context, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	out, err := userbiz.SyncUserDevice(ctx, s.store, userv1.SyncUserDeviceReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.SyncUserDeviceRespFromMoe(out), nil
}
