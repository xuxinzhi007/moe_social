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
func Login(ctx context.Context, db *gorm.DB, email, username, password string) (model.User, string, error) {
	if db == nil {
		return model.User{}, "", gorm.ErrInvalidDB
	}
	var user model.User
	var err error

	email = strings.TrimSpace(email)
	username = strings.TrimSpace(username)

	if email != "" {
		emailNorm := strings.ToLower(email)
		err = db.WithContext(ctx).Where("LOWER(TRIM(email)) = ?", emailNorm).First(&user).Error
	} else if username != "" {
		if isTenDigitMoe(username) {
			err = db.WithContext(ctx).Where("moe_no = ?", username).First(&user).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				err = db.WithContext(ctx).Where("username = ?", username).First(&user).Error
			}
		} else {
			err = db.WithContext(ctx).Where("username = ?", username).First(&user).Error
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
	if _, err := utils.EnsureUserMoeNo(db, user.ID); err != nil {
		return model.User{}, "", err
	}
	_ = db.WithContext(ctx).First(&user, user.ID).Error
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return model.User{}, "", err
	}
	return user, token, nil
}

// Register 注册新用户。
func Register(ctx context.Context, db *gorm.DB, username, email, password string) (model.User, string, error) {
	if db == nil {
		return model.User{}, "", gorm.ErrInvalidDB
	}
	username = strings.TrimSpace(username)
	emailNorm := strings.ToLower(strings.TrimSpace(email))
	if username == "" || emailNorm == "" {
		return model.User{}, "", ErrInvalidArgument
	}

	var existing model.User
	if err := db.WithContext(ctx).Where("username = ?", username).First(&existing).Error; err == nil {
		return model.User{}, "", ErrAlreadyExists
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, "", err
	}
	if err := db.WithContext(ctx).Where("LOWER(TRIM(email)) = ?", emailNorm).First(&existing).Error; err == nil {
		return model.User{}, "", ErrAlreadyExists
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, "", err
	}

	user := model.User{
		Username: username,
		Password: password,
		Email:    emailNorm,
		Avatar:   "https://picsum.photos/150",
		IsVip:    false,
	}
	if err := db.WithContext(ctx).Create(&user).Error; err != nil {
		return model.User{}, "", err
	}
	if _, err := utils.EnsureUserMoeNo(db, user.ID); err != nil {
		return model.User{}, "", err
	}
	_ = db.WithContext(ctx).First(&user, user.ID).Error
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return model.User{}, "", err
	}
	return user, token, nil
}

// GetByID 按主键查询用户。
func GetByID(ctx context.Context, db *gorm.DB, userID uint) (model.User, error) {
	if db == nil {
		return model.User{}, gorm.ErrInvalidDB
	}
	var user model.User
	err := db.WithContext(ctx).First(&user, userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, ErrNotFound
	}
	if err != nil {
		return model.User{}, err
	}
	if _, err := utils.EnsureUserMoeNo(db, user.ID); err != nil {
		return model.User{}, err
	}
	_ = db.WithContext(ctx).First(&user, user.ID).Error
	return user, nil
}
