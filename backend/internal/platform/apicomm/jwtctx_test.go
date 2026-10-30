package apicomm

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestRequireSelfOrUnbound(t *testing.T) {
	t.Run("fills empty target from JWT actor", func(t *testing.T) {
		ctx := context.WithValue(context.Background(), "userId", "42")
		uid, err := RequireSelfOrUnbound(ctx, "")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if uid != "42" {
			t.Fatalf("uid = %q, want 42", uid)
		}
	})

	t.Run("allows matching target and JWT actor", func(t *testing.T) {
		ctx := context.WithValue(context.Background(), "userId", "42")
		uid, err := RequireSelfOrUnbound(ctx, "42")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if uid != "42" {
			t.Fatalf("uid = %q, want 42", uid)
		}
	})

	t.Run("rejects IDOR mismatch between target and JWT actor", func(t *testing.T) {
		ctx := context.WithValue(context.Background(), "userId", "42")
		_, err := RequireSelfOrUnbound(ctx, "99")
		if status.Code(err) != codes.PermissionDenied {
			t.Fatalf("code = %v, want PermissionDenied", status.Code(err))
		}
	})

	t.Run("passes through when no JWT in context (internal call)", func(t *testing.T) {
		uid, err := RequireSelfOrUnbound(context.Background(), "99")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if uid != "99" {
			t.Fatalf("uid = %q, want 99", uid)
		}
	})
}
