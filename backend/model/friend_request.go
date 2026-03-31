package model

import "time"

// FriendRequest 好友申请（同意后双方互相关注，便于沿用原有关注流逻辑）
type FriendRequest struct {
	ID         uint      `gorm:"primarykey" json:"id"`
	FromUserID uint      `gorm:"not null;index;uniqueIndex:idx_friend_from_to,priority:1" json:"from_user_id"`
	ToUserID   uint      `gorm:"not null;index;uniqueIndex:idx_friend_from_to,priority:2" json:"to_user_id"`
	Status     string    `gorm:"size:20;not null;default:pending;index" json:"status"` // pending, accepted, rejected
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}
