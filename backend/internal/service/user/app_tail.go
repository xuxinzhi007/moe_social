// Package userapp F109 user tail RPC → biz wrappers.
package userapp

import (
	"context"

	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
)

func (s *AppService) GetUsers(ctx context.Context, in *userv1.GetUsersReq) (*userv1.GetUsersResp, error) {
	return userbiz.GetUsers(ctx, s.store, in)
}

func (s *AppService) GetUserCount(ctx context.Context, in *userv1.GetUserCountReq) (*userv1.GetUserCountResp, error) {
	return userbiz.GetUserCount(ctx, s.store, in)
}

func (s *AppService) GetUserByEmail(ctx context.Context, in *userv1.GetUserByEmailReq) (*userv1.GetUserByEmailResp, error) {
	return userbiz.GetUserByEmail(ctx, s.store, in)
}

func (s *AppService) UpdateUserInfo(ctx context.Context, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	return userbiz.UpdateUserInfo(ctx, s.store, in)
}

func (s *AppService) UpdateUserPassword(ctx context.Context, in *userv1.UpdateUserPasswordReq) (*userv1.UpdateUserPasswordResp, error) {
	return userbiz.UpdateUserPassword(ctx, s.store, in)
}

func (s *AppService) ResetPassword(ctx context.Context, in *userv1.ResetPasswordReq) (*userv1.ResetPasswordResp, error) {
	return userbiz.ResetPassword(ctx, s.store, in)
}

func (s *AppService) DeleteUser(ctx context.Context, in *userv1.DeleteUserReq) (*userv1.DeleteUserResp, error) {
	return userbiz.DeleteUser(ctx, s.store, in)
}

func (s *AppService) CreateVipOrder(ctx context.Context, in *vipv1.CreateVipOrderReq) (*vipv1.CreateVipOrderResp, error) {
	return userbiz.CreateVipOrder(ctx, s.store, in)
}

func (s *AppService) UpdateUserVip(ctx context.Context, in *vipv1.UpdateUserVipReq) (*vipv1.UpdateUserVipResp, error) {
	return userbiz.UpdateUserVip(ctx, s.store, in)
}

func (s *AppService) SyncUserVipStatus(ctx context.Context, in *vipv1.SyncUserVipStatusReq) (*vipv1.SyncUserVipStatusResp, error) {
	return userbiz.SyncUserVipStatus(ctx, s.store, in)
}

func (s *AppService) UpdateAutoRenew(ctx context.Context, in *vipv1.UpdateAutoRenewReq) (*vipv1.UpdateAutoRenewResp, error) {
	return userbiz.UpdateAutoRenew(ctx, s.store, in)
}

func (s *AppService) GetVipRecords(ctx context.Context, in *vipv1.GetVipRecordsReq) (*vipv1.GetVipRecordsResp, error) {
	return userbiz.GetVipRecords(ctx, s.store, in)
}

func (s *AppService) GetUserActiveVipRecord(ctx context.Context, in *vipv1.GetUserActiveVipRecordReq) (*vipv1.GetUserActiveVipRecordResp, error) {
	return userbiz.GetUserActiveVipRecord(ctx, s.store, in)
}

func (s *AppService) GetTransactions(ctx context.Context, in *userv1.GetTransactionsReq) (*userv1.GetTransactionsResp, error) {
	return userbiz.GetTransactions(ctx, s.store, in)
}

func (s *AppService) GetTransaction(ctx context.Context, in *userv1.GetTransactionReq) (*userv1.GetTransactionResp, error) {
	return userbiz.GetTransaction(ctx, s.store, in)
}

func (s *AppService) Recharge(ctx context.Context, in *userv1.RechargeReq) (*userv1.RechargeResp, error) {
	return userbiz.Recharge(ctx, s.store, in)
}

func (s *AppService) FeishuLogin(ctx context.Context, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	return userbiz.FeishuLogin(ctx, s.store, in)
}

func (s *AppService) FeishuAuthorizeURL(ctx context.Context, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	return userbiz.FeishuAuthorizeURL(ctx, in)
}

func (s *AppService) BindFeishu(ctx context.Context, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	return userbiz.BindFeishu(ctx, s.store, in)
}

func (s *AppService) UnbindFeishu(ctx context.Context, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	return userbiz.UnbindFeishu(ctx, s.store, in)
}

func (s *AppService) SendFeishuTestCard(ctx context.Context, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	return userbiz.SendFeishuTestCard(ctx, s.store, in)
}

func (s *AppService) WechatLogin(ctx context.Context, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	return userbiz.WechatLogin(ctx, s.store, in)
}

func (s *AppService) WechatAuthorizeURL(ctx context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	return userbiz.WechatAuthorizeURL(ctx, in)
}

func (s *AppService) ListUserDevices(ctx context.Context, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	return userbiz.ListUserDevices(ctx, s.store, in)
}

func (s *AppService) SyncUserDevice(ctx context.Context, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	return userbiz.SyncUserDevice(ctx, s.store, in)
}
