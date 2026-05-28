package userbiz

import (
	"context"
	"time"
)

// VipStatus 用户 VIP 状态摘要。
type VipStatus struct {
	IsVip     bool
	ExpiresAt string
	AutoRenew bool
}

// GetVipStatus 查询用户 VIP 状态。
func GetVipStatus(ctx context.Context, store UserStore, userID uint) (VipStatus, error) {
	user, err := GetByID(ctx, store, userID)
	if err != nil {
		return VipStatus{}, err
	}
	exp := ""
	if user.VipEndAt != nil {
		exp = user.VipEndAt.Format("2006-01-02 15:04:05")
	}
	return VipStatus{
		IsVip:     user.IsVip,
		ExpiresAt: exp,
		AutoRenew: user.AutoRenew,
	}, nil
}

// CheckVipActive 是否仍在 VIP 有效期内。
func CheckVipActive(ctx context.Context, store UserStore, userID uint) (bool, error) {
	user, err := GetByID(ctx, store, userID)
	if err != nil {
		return false, err
	}
	if !user.IsVip {
		return false, nil
	}
	if user.VipEndAt == nil {
		return true, nil
	}
	return user.VipEndAt.After(time.Now()), nil
}
