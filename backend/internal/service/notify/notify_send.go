package notifyapp

import (
	"context"
	notifybiz "backend/internal/biz/notify"
)

// Broadcast 全员广播。
func (s *AppService) Broadcast(ctx context.Context, title, content string) (int32, error) {
	return notifybiz.Broadcast(ctx, s.store, title, content)
}

// SendToUser 单用户系统通知。
func (s *AppService) SendToUser(ctx context.Context, userID, title, content string) (uint, error) {
	return notifybiz.SendToUser(ctx, s.store, userID, title, content)
}
