package chatgrpc

import (
	"context"
	"encoding/json"

	chatv1 "backend/api/chat/v1"
)

func (s *Server) BroadcastPushNotification(ctx context.Context, in *chatv1.BroadcastPushNotificationReq) (*chatv1.BroadcastPushNotificationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	data := decodeJSONData(in.GetDataJson())
	_ = app.BroadcastPushNotification(ctx, in.GetType(), data)
	return &chatv1.BroadcastPushNotificationResp{}, nil
}

func (s *Server) SendPushNotification(ctx context.Context, in *chatv1.SendPushNotificationReq) (*chatv1.SendPushNotificationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	data := decodeJSONData(in.GetDataJson())
	delivered := app.PushNotification(ctx, in.GetUserId(), in.GetType(), data)
	return &chatv1.SendPushNotificationResp{Delivered: delivered}, nil
}

func (s *Server) SendBatchPushNotification(ctx context.Context, in *chatv1.SendBatchPushNotificationReq) (*chatv1.SendBatchPushNotificationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	data := decodeJSONData(in.GetDataJson())
	_ = app.PushBatchNotification(ctx, in.GetUserIds(), in.GetType(), data)
	return &chatv1.SendBatchPushNotificationResp{}, nil
}

func decodeJSONData(raw string) any {
	if raw == "" {
		return nil
	}
	var out any
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return raw
	}
	return out
}
