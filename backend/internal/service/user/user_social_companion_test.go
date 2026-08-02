package userapp

import (
	"context"
	"testing"

	"backend/model"
)

func TestRecordFriendRequestResolutionProjectsMetadataOnly(t *testing.T) {
	type capturedEvent struct {
		userID    uint
		eventType string
		sourceID  uint
		payload   map[string]interface{}
	}
	var events []capturedEvent
	service := &AppService{}
	service.SetCompanionEventRecorder(func(
		_ context.Context,
		userID uint,
		eventType string,
		sourceID uint,
		payload map[string]interface{},
	) error {
		events = append(events, capturedEvent{userID, eventType, sourceID, payload})
		return nil
	})

	service.recordFriendRequestResolution(context.Background(), &model.FriendRequest{
		ID:         42,
		FromUserID: 7,
		ToUserID:   8,
	}, "accepted")

	if len(events) != 2 {
		t.Fatalf("events=%d, want one event per participant", len(events))
	}
	for _, event := range events {
		if event.sourceID != 42 || event.eventType != "friend_request_accepted" {
			t.Fatalf("event=%+v, want accepted relation event", event)
		}
		if _, exists := event.payload["content"]; exists {
			t.Fatalf("event payload must not contain content: %+v", event.payload)
		}
	}
}
