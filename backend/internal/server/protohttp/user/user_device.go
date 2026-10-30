package userhttp

import (
	"context"

	userv1 "backend/api/user/v1"
	apicomm "backend/internal/platform/apicomm"
)

func (s *Server) SyncUserDevice(ctx context.Context, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.SyncUserDevice(ctx, in)
}

func (s *Server) ListUserDevices(ctx context.Context, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.ListUserDevices(ctx, in)
}
