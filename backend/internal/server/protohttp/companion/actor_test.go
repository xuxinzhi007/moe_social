package companionhttp

import (
	"context"
	"testing"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func TestActorUserID(t *testing.T) {
	ctx := context.WithValue(context.Background(), "userId", "42")
	userID, err := actorUserID(ctx)
	if err != nil {
		t.Fatalf("actorUserID() error = %v", err)
	}
	if userID != 42 {
		t.Fatalf("actorUserID() = %d, want 42", userID)
	}
}

func TestActorUserIDRequiresAuthentication(t *testing.T) {
	_, err := actorUserID(context.Background())
	if !kerrors.IsUnauthorized(err) {
		t.Fatalf("actorUserID() error = %v, want unauthorized", err)
	}
}
