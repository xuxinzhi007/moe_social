package usergw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	notifybiz "backend/internal/biz/notify"
	userv1 "backend/api/user/v1"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) GetUserAvatar(ctx context.Context, in *moe.GetUserAvatarReq, opts ...grpc.CallOption) (*moe.GetUserAvatarResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetUserAvatar(ctx, userv1.GetUserAvatarReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.GetUserAvatarRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdateUserAvatar(ctx context.Context, in *moe.UpdateUserAvatarReq, opts ...grpc.CallOption) (*moe.UpdateUserAvatarResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdateUserAvatar(ctx, userv1.UpdateUserAvatarReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return userv1.UpdateUserAvatarRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateNotification(ctx context.Context, in *moe.CreateNotificationReq, opts ...grpc.CallOption) (*moe.CreateNotificationResp, error) {
	if g != nil && g.local != nil && g.local.Notify() != nil {
		if err := notifybiz.CreateInbox(ctx, g.local.Notify(), in); err != nil {
			return nil, err
		}
		return &moe.CreateNotificationResp{}, nil
	}
	return nil, gwutil.ErrUnavailable
}
