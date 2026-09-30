package userbiz

import (
	"context"
	"errors"
	"testing"
)

func TestFollowRejectsSelf(t *testing.T) {
	err := Follow(context.Background(), nil, 7, 7)
	if !errors.Is(err, ErrFollowSelf) {
		t.Fatalf("Follow self = %v, want ErrFollowSelf", err)
	}
}
