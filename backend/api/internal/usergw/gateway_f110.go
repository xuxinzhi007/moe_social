package usergw

import (
	"context"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUserAvatar(ctx context.Context, in *super.GetUserAvatarReq, opts ...grpc.CallOption) (*super.GetUserAvatarResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAvatar(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserAvatar(ctx, in, opts...)
}

func (g *Gateway) UpdateUserAvatar(ctx context.Context, in *super.UpdateUserAvatarReq, opts ...grpc.CallOption) (*super.UpdateUserAvatarResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserAvatar(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.UpdateUserAvatar(ctx, in, opts...)
}

func (g *Gateway) CreateNotification(ctx context.Context, in *super.CreateNotificationReq, opts ...grpc.CallOption) (*super.CreateNotificationResp, error) {
	if g != nil && g.local != nil && g.local.DB() != nil {
		if err := notifybiz.CreateInbox(ctx, g.local.DB(), in); err != nil {
			return nil, err
		}
		return &super.CreateNotificationResp{}, nil
	}
	if g == nil || g.super == nil {
		return &super.CreateNotificationResp{}, nil
	}
	return g.super.CreateNotification(ctx, in, opts...)
}
