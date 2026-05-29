package adminbiz

import (
	"context"
	"errors"
	"strings"

	adminv1 "backend/api/admin/v1"

	"gorm.io/gorm"
)

var (
	ErrInvalidUserID   = errors.New("invalid user id")
	ErrUserNotFound    = errors.New("user not found")
	ErrInvalidUserRole = errors.New("invalid role")
)

// UpdateUserInput Admin 用户部分更新。
type UpdateUserInput struct {
	UserID          uint
	Role            string
	IsVip           bool
	UpdateIsVip     bool
	Signature       string
	UpdateSignature bool
	Avatar          string
	UpdateAvatar    bool
}

// UpdateUser 更新 App 用户字段。
func UpdateUser(ctx context.Context, store AdminStore, in UpdateUserInput) (*adminv1.User, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if in.UserID == 0 {
		return nil, ErrInvalidUserID
	}

	user, err := store.GetUserByID(ctx, in.UserID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	updates := map[string]interface{}{}
	if role := strings.TrimSpace(in.Role); role != "" {
		switch role {
		case "user", "admin", "super_admin":
			updates["role"] = role
		default:
			return nil, ErrInvalidUserRole
		}
	}
	if in.UpdateIsVip {
		updates["is_vip"] = in.IsVip
	}
	if in.UpdateSignature {
		updates["signature"] = strings.TrimSpace(in.Signature)
	}
	if in.UpdateAvatar {
		updates["avatar"] = strings.TrimSpace(in.Avatar)
	}
	if len(updates) == 0 {
		return userModelToAdminV1(&user), nil
	}

	if err := store.UpdateUserFields(ctx, user.ID, updates); err != nil {
		return nil, err
	}
	user, err = store.ReloadUser(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	return userModelToAdminV1(&user), nil
}
