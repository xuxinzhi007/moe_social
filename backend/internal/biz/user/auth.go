package userbiz

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

func isTenDigitMoe(s string) bool {
	if len(s) != 10 {
		return false
	}
	for i := 0; i < 10; i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

// Login 邮箱或用户名登录，返回用户与 JWT。
func Login(ctx context.Context, store UserStore, email, username, password string) (model.User, string, error) {
	if store == nil {
		return model.User{}, "", gorm.ErrInvalidDB
	}
	var user model.User
	var err error

	email = strings.TrimSpace(email)
	username = strings.TrimSpace(username)

	if email != "" {
		emailNorm := strings.ToLower(email)
		user, err = store.FindUserByNormalizedEmail(ctx, emailNorm)
	} else if username != "" {
		if isTenDigitMoe(username) {
			user, err = store.FindUserByMoeNo(ctx, username)
			if errors.Is(err, gorm.ErrRecordNotFound) {
				user, err = store.FindUserByUsername(ctx, username)
			}
		} else {
			user, err = store.FindUserByUsername(ctx, username)
		}
	} else {
		return model.User{}, "", ErrInvalidArgument
	}

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return model.User{}, "", ErrUnauthorized
		}
		return model.User{}, "", err
	}
	if !user.CheckPassword(password) {
		return model.User{}, "", ErrUnauthorized
	}
	if _, err := utils.EnsureUserMoeNo(store.Raw(), user.ID); err != nil {
		return model.User{}, "", err
	}
	user, _ = store.ReloadUser(ctx, user.ID)
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return model.User{}, "", err
	}
	return user, token, nil
}

// Register 注册新用户。
func Register(ctx context.Context, store UserStore, username, email, password string) (model.User, string, error) {
	if store == nil {
		return model.User{}, "", gorm.ErrInvalidDB
	}
	username = strings.TrimSpace(username)
	emailNorm := strings.ToLower(strings.TrimSpace(email))
	if username == "" || emailNorm == "" {
		return model.User{}, "", ErrInvalidArgument
	}

	exists, err := store.ExistsUserByUsername(ctx, username)
	if err != nil {
		return model.User{}, "", err
	}
	if exists {
		return model.User{}, "", ErrAlreadyExists
	}
	exists, err = store.ExistsUserByNormalizedEmail(ctx, emailNorm)
	if err != nil {
		return model.User{}, "", err
	}
	if exists {
		return model.User{}, "", ErrAlreadyExists
	}

	user := model.User{
		Username: username,
		Password: password,
		Email:    emailNorm,
		Avatar:   "https://picsum.photos/150",
		IsVip:    false,
	}
	if err := store.CreateUser(ctx, &user); err != nil {
		return model.User{}, "", err
	}
	if _, err := utils.EnsureUserMoeNo(store.Raw(), user.ID); err != nil {
		return model.User{}, "", err
	}
	user, _ = store.ReloadUser(ctx, user.ID)
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return model.User{}, "", err
	}
	return user, token, nil
}

// GetByID 按主键查询用户。
func GetByID(ctx context.Context, store UserStore, userID uint) (model.User, error) {
	if store == nil {
		return model.User{}, gorm.ErrInvalidDB
	}
	user, err := store.GetUserByID(ctx, userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	if _, err := utils.EnsureUserMoeNo(store.Raw(), user.ID); err != nil {
		return model.User{}, err
	}
	user, _ = store.ReloadUser(ctx, user.ID)
	return user, nil
}
