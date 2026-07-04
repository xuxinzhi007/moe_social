package chatdelivery

import (
	"context"

	chatv1 "backend/api/chat/v1"
	userv1 "backend/api/user/v1"
	chatbiz "backend/internal/biz/chat"
	notifybiz "backend/internal/biz/notify"
	"backend/internal/platform/svc"
	chatapp "backend/internal/service/chat"
	userapp "backend/internal/service/user"
)

// UserProfileAdapter wraps UserApp for chat WebSocket profile reads.
type UserProfileAdapter struct {
	app *userapp.AppService
}

// GetUser loads a user profile by id.
func (a *UserProfileAdapter) GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error) {
	if a == nil || a.app == nil {
		return nil, errUnavailable
	}
	return a.app.GetUser(ctx, in)
}

// ChatPMAdapter wraps ChatApp for private message persistence.
type ChatPMAdapter struct {
	app *chatapp.AppService
}

// SendPrivateMessage persists a private message.
func (a *ChatPMAdapter) SendPrivateMessage(
	ctx context.Context,
	in *chatv1.SendPrivateMessageRequest,
) (*chatv1.SendPrivateMessageReply, error) {
	if a == nil || a.app == nil {
		return nil, errUnavailable
	}
	return a.app.SendPrivateMessage(ctx, in)
}

// NotificationAdapter writes inbox notifications via UserApp notify store.
type NotificationAdapter struct {
	store notifybiz.NotifyStore
}

// CreateNotification writes a notification to the user's inbox.
func (a *NotificationAdapter) CreateNotification(
	ctx context.Context,
	in *userv1.CreateNotificationReq,
) (*userv1.CreateNotificationResp, error) {
	if a == nil || a.store == nil || in == nil {
		return nil, errUnavailable
	}
	if err := notifybiz.CreateInbox(ctx, a.store, in); err != nil {
		return nil, err
	}
	return &userv1.CreateNotificationResp{}, nil
}

// ChatWSDepsFrom builds chat WebSocket dependencies from ServiceContext.
func ChatWSDepsFrom(svcCtx *svc.ServiceContext) chatbiz.ChatWSDeps {
	deps := chatbiz.ChatWSDeps{
		Delivery: chatbiz.DeliveryDeps{},
	}
	if svcCtx == nil {
		return deps
	}
	if svcCtx.Domains.Access.UserApp != nil {
		deps.Delivery.UserReader = &UserProfileAdapter{app: svcCtx.Domains.Access.UserApp}
		deps.Delivery.NotifyStore = svcCtx.Domains.Access.UserApp.Notify()
		if deps.Delivery.NotifyStore != nil {
			deps.Delivery.NotifyRPC = &NotificationAdapter{store: deps.Delivery.NotifyStore}
		}
	}
	if svcCtx.Domains.Community.ChatApp != nil {
		deps.PM = &ChatPMAdapter{app: svcCtx.Domains.Community.ChatApp}
	}
	return deps
}
