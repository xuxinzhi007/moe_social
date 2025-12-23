package model

import (
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	Username    string         `gorm:"uniqueIndex;size:50;not null" json:"username"`
	Password    string         `gorm:"size:100;not null" json:"-"`
	Email       string         `gorm:"uniqueIndex;size:100;not null" json:"email"`
	Avatar      string         `gorm:"type:text" json:"avatar"` // 头像URL，支持长URL（如base64 data URI）
	IsVip       bool           `gorm:"default:false" json:"is_vip"`
	VipStartAt  *time.Time     `json:"vip_start_at,omitempty"`
	VipEndAt    *time.Time     `json:"vip_end_at,omitempty"`
	AutoRenew   bool           `gorm:"default:false" json:"auto_renew"` // 自动续费
	Balance     float64        `gorm:"default:0" json:"balance"`        // 钱包余额
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// BeforeSave 保存前钩子，自动哈希密码
func (u *User) BeforeSave(tx *gorm.DB) error {
	// 只有当密码被修改时才重新哈希
	if u.Password != "" {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		u.Password = string(hashedPassword)
	}
	return nil
}

// CheckPassword 检查密码是否正确
func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}
