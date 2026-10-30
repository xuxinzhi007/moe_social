package gifthttp

import (
	"context"
	"testing"

	giftv1 "backend/api/gift/v1"
	giftbiz "backend/internal/biz/gift"
	giftapp "backend/internal/service/gift"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestMapGiftError(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
		code codes.Code
	}{
		{"invalid user", giftbiz.ErrInvalidUserID, codes.InvalidArgument},
		{"invalid gift", giftbiz.ErrInvalidGiftID, codes.InvalidArgument},
		{"not found", giftbiz.ErrGiftNotFound, codes.NotFound},
		{"insufficient balance", giftbiz.ErrInsufficientBal, codes.FailedPrecondition},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got := status.Code(mapGiftError(tc.err))
			if got != tc.code {
				t.Fatalf("code = %v, want %v", got, tc.code)
			}
		})
	}
}

func TestGiftIDORRejected(t *testing.T) {
	srv := New(&giftapp.AppService{})
	ctx := context.WithValue(context.Background(), "userId", "10")

	_, err := srv.PurchaseGift(ctx, &giftv1.PurchaseGiftRequest{UserId: "20", GiftId: "1", Quantity: 1})
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("PurchaseGift IDOR status = %v, want PermissionDenied", status.Code(err))
	}

	_, err = srv.SendGift(ctx, &giftv1.SendGiftRequest{FromUserId: "20", ToUserId: "30", GiftId: "1", Quantity: 1})
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("SendGift IDOR status = %v, want PermissionDenied", status.Code(err))
	}
}
