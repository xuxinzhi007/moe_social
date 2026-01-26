package model

import (
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID              uint           `gorm:"primarykey" json:"id"`
	Username        string         `gorm:"uniqueIndex;size:50;not null" json:"username"`
	Password        string         `gorm:"size:100;not null" json:"-"`
	Email           string         `gorm:"uniqueIndex;size:100;not null" json:"email"`
	Avatar          string         `gorm:"type:text" json:"avatar"`   // 头像URL，支持长URL（如base64 data URI）
	Signature       string         `gorm:"size:100" json:"signature"` // 个性签名，最多100字符
	Gender          string         `gorm:"size:10" json:"gender"`     // 性别：male/female/secret
	Birthday        *time.Time     `json:"birthday,omitempty"`        // 生日
	IsVip           bool           `gorm:"default:false" json:"is_vip"`
	VipStartAt      *time.Time     `json:"vip_start_at,omitempty"`
	VipEndAt        *time.Time     `json:"vip_end_at,omitempty"`
	AutoRenew       bool           `gorm:"default:false" json:"auto_renew"`   // 自动续费
	Balance         float64        `gorm:"default:0" json:"balance"`          // 钱包余额
	Inventory       string         `gorm:"type:text" json:"inventory"`        // JSON: ["item1", "item2"]
	EquippedFrameId string         `gorm:"size:100" json:"equipped_frame_id"` // 佩戴的头像框ID
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`

	// 关注相关关联
	Followings []Follow `gorm:"foreignKey:FollowerID" json:"-"`  // 我关注的人
	Followers  []Follow `gorm:"foreignKey:FollowingID" json:"-"` // 关注我的人
}

// BeforeSave 保存前钩子，自动哈希密码
func (u *User) BeforeSave(tx *gorm.DB) error {
	// Only hash when Password field is actually changed.
	// This avoids re-hashing the already-hashed password during unrelated updates.
	if tx != nil && tx.Statement != nil && !tx.Statement.Changed("Password") {
		return nil
	}

	// Extra guard: avoid re-hashing an already-hashed bcrypt password.
	if u.Password != "" && !looksLikeBcryptHash(u.Password) {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		u.Password = string(hashedPassword)
	}
	return nil
}

func looksLikeBcryptHash(s string) bool {
	// bcrypt hashes look like: $2a$10$... (60 chars)
	if len(s) < 4 {
		return false
	}
	if !(strings.HasPrefix(s, "$2a$") || strings.HasPrefix(s, "$2b$") || strings.HasPrefix(s, "$2y$")) {
		return false
	}
	// Typical bcrypt hash length is 60; allow variants but avoid hashing again.
	return len(s) >= 55
}

// CheckPassword 检查密码是否正确
func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}
