// Package userapp 用户设备同步。
package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 用户设备同步。

func (s *AppService) ListUserDevices(ctx context.Context, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	return userbiz.ListUserDevices(ctx, s.store, in)
}

func (s *AppService) SyncUserDevice(ctx context.Context, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	return userbiz.SyncUserDevice(ctx, s.store, in)
}
