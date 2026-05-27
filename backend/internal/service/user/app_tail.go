// Package userapp F109 user tail RPC → biz wrappers.
package userapp

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/pb/super"
)

func (s *AppService) GetUsers(ctx context.Context, in *super.GetUsersReq) (*super.GetUsersResp, error) {
	return userbiz.GetUsers(ctx, s.db, in)
}

func (s *AppService) GetUserCount(ctx context.Context, in *super.GetUserCountReq) (*super.GetUserCountResp, error) {
	return userbiz.GetUserCount(ctx, s.db, in)
}

func (s *AppService) GetUserByEmail(ctx context.Context, in *super.GetUserByEmailReq) (*super.GetUserByEmailResp, error) {
	return userbiz.GetUserByEmail(ctx, s.db, in)
}

func (s *AppService) UpdateUserInfo(ctx context.Context, in *super.UpdateUserInfoReq) (*super.UpdateUserInfoResp, error) {
	return userbiz.UpdateUserInfo(ctx, s.db, in)
}

func (s *AppService) UpdateUserPassword(ctx context.Context, in *super.UpdateUserPasswordReq) (*super.UpdateUserPasswordResp, error) {
	return userbiz.UpdateUserPassword(ctx, s.db, in)
}

func (s *AppService) ResetPassword(ctx context.Context, in *super.ResetPasswordReq) (*super.ResetPasswordResp, error) {
	return userbiz.ResetPassword(ctx, s.db, in)
}

func (s *AppService) DeleteUser(ctx context.Context, in *super.DeleteUserReq) (*super.DeleteUserResp, error) {
	return userbiz.DeleteUser(ctx, s.db, in)
}

func (s *AppService) CreateVipOrder(ctx context.Context, in *super.CreateVipOrderReq) (*super.CreateVipOrderResp, error) {
	return userbiz.CreateVipOrder(ctx, s.db, in)
}

func (s *AppService) UpdateUserVip(ctx context.Context, in *super.UpdateUserVipReq) (*super.UpdateUserVipResp, error) {
	return userbiz.UpdateUserVip(ctx, s.db, in)
}

func (s *AppService) SyncUserVipStatus(ctx context.Context, in *super.SyncUserVipStatusReq) (*super.SyncUserVipStatusResp, error) {
	return userbiz.SyncUserVipStatus(ctx, s.db, in)
}

func (s *AppService) UpdateAutoRenew(ctx context.Context, in *super.UpdateAutoRenewReq) (*super.UpdateAutoRenewResp, error) {
	return userbiz.UpdateAutoRenew(ctx, s.db, in)
}

func (s *AppService) GetVipRecords(ctx context.Context, in *super.GetVipRecordsReq) (*super.GetVipRecordsResp, error) {
	return userbiz.GetVipRecords(ctx, s.db, in)
}

func (s *AppService) GetUserActiveVipRecord(ctx context.Context, in *super.GetUserActiveVipRecordReq) (*super.GetUserActiveVipRecordResp, error) {
	return userbiz.GetUserActiveVipRecord(ctx, s.db, in)
}

func (s *AppService) GetTransactions(ctx context.Context, in *super.GetTransactionsReq) (*super.GetTransactionsResp, error) {
	return userbiz.GetTransactions(ctx, s.db, in)
}

func (s *AppService) GetTransaction(ctx context.Context, in *super.GetTransactionReq) (*super.GetTransactionResp, error) {
	return userbiz.GetTransaction(ctx, s.db, in)
}

func (s *AppService) Recharge(ctx context.Context, in *super.RechargeReq) (*super.RechargeResp, error) {
	return userbiz.Recharge(ctx, s.db, in)
}

func (s *AppService) FeishuLogin(ctx context.Context, in *super.FeishuLoginReq) (*super.FeishuLoginResp, error) {
	return userbiz.FeishuLogin(ctx, s.db, in)
}

func (s *AppService) FeishuAuthorizeURL(ctx context.Context, in *super.FeishuAuthorizeURLReq) (*super.FeishuAuthorizeURLResp, error) {
	return userbiz.FeishuAuthorizeURL(ctx, in)
}

func (s *AppService) BindFeishu(ctx context.Context, in *super.BindFeishuReq) (*super.BindFeishuResp, error) {
	return userbiz.BindFeishu(ctx, s.db, in)
}

func (s *AppService) UnbindFeishu(ctx context.Context, in *super.UnbindFeishuReq) (*super.UnbindFeishuResp, error) {
	return userbiz.UnbindFeishu(ctx, s.db, in)
}

func (s *AppService) SendFeishuTestCard(ctx context.Context, in *super.SendFeishuTestCardReq) (*super.SendFeishuTestCardResp, error) {
	return userbiz.SendFeishuTestCard(ctx, s.db, in)
}

func (s *AppService) WechatLogin(ctx context.Context, in *super.WechatLoginReq) (*super.WechatLoginResp, error) {
	return userbiz.WechatLogin(ctx, s.db, in)
}

func (s *AppService) WechatAuthorizeURL(ctx context.Context, in *super.WechatAuthorizeURLReq) (*super.WechatAuthorizeURLResp, error) {
	return userbiz.WechatAuthorizeURL(ctx, in)
}

func (s *AppService) ListUserDevices(ctx context.Context, in *super.ListUserDevicesReq) (*super.ListUserDevicesResp, error) {
	return userbiz.ListUserDevices(ctx, s.db, in)
}

func (s *AppService) SyncUserDevice(ctx context.Context, in *super.SyncUserDeviceReq) (*super.SyncUserDeviceResp, error) {
	return userbiz.SyncUserDevice(ctx, s.db, in)
}
