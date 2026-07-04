package chathttp

import (
	"context"
	"testing"

	chatv1 "backend/api/chat/v1"
)

func TestFillPrivateMessageListRequestKeepsPeerID(t *testing.T) {
	in := &chatv1.ListPrivateMessagesRequest{ViewerId: "1", PeerId: "2"}
	if err := fillPrivateMessageListRequest(context.Background(), in); err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if in.GetPeerId() != "2" {
		t.Fatalf("peer_id = %q, want 2", in.GetPeerId())
	}
}

func TestFillPrivateConversationsRequestRequiresAuth(t *testing.T) {
	in := &chatv1.ListPrivateConversationsRequest{}
	err := fillPrivateConversationsRequest(context.Background(), in)
	if err == nil {
		t.Fatal("expected unauthenticated error")
	}
}
