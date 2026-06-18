// Package userapp VIP 状态与订单。
package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	vipv1 "backend/api/vip/v1"
)

// Package userapp VIP 状态与订单。

// GetUserVipStatus VIP 状态。
func (s *AppService) GetUserVipStatus(ctx context.Context, in *vipv1.GetUserVipStatusReq) (*vipv1.GetUserVipStatusResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	st, err := userbiz.GetVipStatus(ctx, s.store, uid)
	if err != nil {
		return nil, err
	}
	return userbiz.GetUserVipStatusRespV1(st), nil
}

// CheckUserVip 是否有效 VIP。
func (s *AppService) CheckUserVip(ctx context.Context, in *vipv1.CheckUserVipReq) (*vipv1.CheckUserVipResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	active, err := userbiz.CheckVipActive(ctx, s.store, uid)
	if err != nil {
		return nil, err
	}
	return &vipv1.CheckUserVipResp{IsVip: active}, nil
}

// GetVipOrders VIP 订单列表。
func (s *AppService) GetVipOrders(ctx context.Context, in *vipv1.GetVipOrdersReq) (*vipv1.GetVipOrdersResp, error) {
	orders, total, err := userbiz.ListVipOrders(ctx, s.store, in.GetUserId(), userbiz.VipOrdersPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return userbiz.VipOrdersRespV1(orders, total), nil
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
