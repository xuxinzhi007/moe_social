package model

import (
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// AdminAccount Moe Admin 运维后台账号（与 App users 分离）。
type AdminAccount struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	Username     string         `gorm:"uniqueIndex;size:50;not null" json:"username"`
	Password     string         `gorm:"size:100;not null" json:"-"`
	Role         string         `gorm:"size:20;not null;default:admin" json:"role"` // admin | super_admin
	LastLoginAt  *time.Time     `json:"last_login_at,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (a *AdminAccount) BeforeSave(tx *gorm.DB) error {
	if a.Password != "" && !looksLikeBcryptHash(a.Password) {
		hashed, err := bcrypt.GenerateFromPassword([]byte(a.Password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		a.Password = string(hashed)
	}
	return nil
}

func (a *AdminAccount) CheckPassword(raw string) bool {
	return bcrypt.CompareHashAndPassword([]byte(a.Password), []byte(raw)) == nil
}
