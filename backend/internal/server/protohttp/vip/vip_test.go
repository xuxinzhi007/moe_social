package viphttp

import (
	"context"
	"testing"

	vipv1 "backend/api/vip/v1"
	userapp "backend/internal/service/user"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestVipIDORAndAdminGuard(t *testing.T) {
	srv := New(&userapp.AppService{})
	userCtx := context.WithValue(context.Background(), "userId", "10")

	// 1. 普通用户不能替别人下单买 VIP
	_, err := srv.CreateVipOrder(userCtx, &vipv1.CreateVipOrderReq{UserId: "20", PlanId: "1"})
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("CreateVipOrder IDOR status = %v, want PermissionDenied", status.Code(err))
	}

	// 2. 普通用户不能调用 UpdateUserVip 免费给自己或他人刷 VIP
	_, err = srv.UpdateUserVip(userCtx, &vipv1.UpdateUserVipReq{UserId: "10", IsVip: true, VipExpires: "2099-01-01 00:00:00"})
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("UpdateUserVip by non-admin status = %v, want PermissionDenied", status.Code(err))
	}
}
