package usergw

import (
	"context"

	notifybiz "backend/internal/biz/notify"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUserAvatar(ctx context.Context, in *moe.GetUserAvatarReq, opts ...grpc.CallOption) (*moe.GetUserAvatarResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserAvatar(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.GetUserAvatar(ctx, in, opts...)
}

func (g *Gateway) UpdateUserAvatar(ctx context.Context, in *moe.UpdateUserAvatarReq, opts ...grpc.CallOption) (*moe.UpdateUserAvatarResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUserAvatar(ctx, in)
	}
	if g == nil || g.super == nil {
		return nil, nil
	}
	return g.super.UpdateUserAvatar(ctx, in, opts...)
}

func (g *Gateway) CreateNotification(ctx context.Context, in *moe.CreateNotificationReq, opts ...grpc.CallOption) (*moe.CreateNotificationResp, error) {
	if g != nil && g.local != nil && g.local.Notify() != nil {
		if err := notifybiz.CreateInbox(ctx, g.local.Notify(), in); err != nil {
			return nil, err
		}
		return &moe.CreateNotificationResp{}, nil
	}
	if g == nil || g.super == nil {
		return &moe.CreateNotificationResp{}, nil
	}
	return g.super.CreateNotification(ctx, in, opts...)
}
