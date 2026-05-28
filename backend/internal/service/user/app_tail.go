// Package userapp F109 user tail RPC → biz wrappers.
package userapp

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/pb/moe"
)

func (s *AppService) GetUsers(ctx context.Context, in *moe.GetUsersReq) (*moe.GetUsersResp, error) {
	return userbiz.GetUsers(ctx, s.db, in)
}

func (s *AppService) GetUserCount(ctx context.Context, in *moe.GetUserCountReq) (*moe.GetUserCountResp, error) {
	return userbiz.GetUserCount(ctx, s.db, in)
}

func (s *AppService) GetUserByEmail(ctx context.Context, in *moe.GetUserByEmailReq) (*moe.GetUserByEmailResp, error) {
	return userbiz.GetUserByEmail(ctx, s.db, in)
}

func (s *AppService) UpdateUserInfo(ctx context.Context, in *moe.UpdateUserInfoReq) (*moe.UpdateUserInfoResp, error) {
	return userbiz.UpdateUserInfo(ctx, s.db, in)
}

func (s *AppService) UpdateUserPassword(ctx context.Context, in *moe.UpdateUserPasswordReq) (*moe.UpdateUserPasswordResp, error) {
	return userbiz.UpdateUserPassword(ctx, s.db, in)
}

func (s *AppService) ResetPassword(ctx context.Context, in *moe.ResetPasswordReq) (*moe.ResetPasswordResp, error) {
	return userbiz.ResetPassword(ctx, s.db, in)
}

func (s *AppService) DeleteUser(ctx context.Context, in *moe.DeleteUserReq) (*moe.DeleteUserResp, error) {
	return userbiz.DeleteUser(ctx, s.db, in)
}

func (s *AppService) CreateVipOrder(ctx context.Context, in *moe.CreateVipOrderReq) (*moe.CreateVipOrderResp, error) {
	return userbiz.CreateVipOrder(ctx, s.db, in)
}

func (s *AppService) UpdateUserVip(ctx context.Context, in *moe.UpdateUserVipReq) (*moe.UpdateUserVipResp, error) {
	return userbiz.UpdateUserVip(ctx, s.db, in)
}

func (s *AppService) SyncUserVipStatus(ctx context.Context, in *moe.SyncUserVipStatusReq) (*moe.SyncUserVipStatusResp, error) {
	return userbiz.SyncUserVipStatus(ctx, s.db, in)
}

func (s *AppService) UpdateAutoRenew(ctx context.Context, in *moe.UpdateAutoRenewReq) (*moe.UpdateAutoRenewResp, error) {
	return userbiz.UpdateAutoRenew(ctx, s.db, in)
}

func (s *AppService) GetVipRecords(ctx context.Context, in *moe.GetVipRecordsReq) (*moe.GetVipRecordsResp, error) {
	return userbiz.GetVipRecords(ctx, s.db, in)
}

func (s *AppService) GetUserActiveVipRecord(ctx context.Context, in *moe.GetUserActiveVipRecordReq) (*moe.GetUserActiveVipRecordResp, error) {
	return userbiz.GetUserActiveVipRecord(ctx, s.db, in)
}

func (s *AppService) GetTransactions(ctx context.Context, in *moe.GetTransactionsReq) (*moe.GetTransactionsResp, error) {
	return userbiz.GetTransactions(ctx, s.db, in)
}

func (s *AppService) GetTransaction(ctx context.Context, in *moe.GetTransactionReq) (*moe.GetTransactionResp, error) {
	return userbiz.GetTransaction(ctx, s.db, in)
}

func (s *AppService) Recharge(ctx context.Context, in *moe.RechargeReq) (*moe.RechargeResp, error) {
	return userbiz.Recharge(ctx, s.db, in)
}

func (s *AppService) FeishuLogin(ctx context.Context, in *moe.FeishuLoginReq) (*moe.FeishuLoginResp, error) {
	return userbiz.FeishuLogin(ctx, s.db, in)
}

func (s *AppService) FeishuAuthorizeURL(ctx context.Context, in *moe.FeishuAuthorizeURLReq) (*moe.FeishuAuthorizeURLResp, error) {
	return userbiz.FeishuAuthorizeURL(ctx, in)
}

func (s *AppService) BindFeishu(ctx context.Context, in *moe.BindFeishuReq) (*moe.BindFeishuResp, error) {
	return userbiz.BindFeishu(ctx, s.db, in)
}

func (s *AppService) UnbindFeishu(ctx context.Context, in *moe.UnbindFeishuReq) (*moe.UnbindFeishuResp, error) {
	return userbiz.UnbindFeishu(ctx, s.db, in)
}

func (s *AppService) SendFeishuTestCard(ctx context.Context, in *moe.SendFeishuTestCardReq) (*moe.SendFeishuTestCardResp, error) {
	return userbiz.SendFeishuTestCard(ctx, s.db, in)
}

func (s *AppService) WechatLogin(ctx context.Context, in *moe.WechatLoginReq) (*moe.WechatLoginResp, error) {
	return userbiz.WechatLogin(ctx, s.db, in)
}

func (s *AppService) WechatAuthorizeURL(ctx context.Context, in *moe.WechatAuthorizeURLReq) (*moe.WechatAuthorizeURLResp, error) {
	return userbiz.WechatAuthorizeURL(ctx, in)
}

func (s *AppService) ListUserDevices(ctx context.Context, in *moe.ListUserDevicesReq) (*moe.ListUserDevicesResp, error) {
	return userbiz.ListUserDevices(ctx, s.db, in)
}

func (s *AppService) SyncUserDevice(ctx context.Context, in *moe.SyncUserDeviceReq) (*moe.SyncUserDeviceResp, error) {
	return userbiz.SyncUserDevice(ctx, s.db, in)
}
