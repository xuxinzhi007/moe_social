package model

import (
	"time"

	"gorm.io/gorm"
)

// Follow 关注关系模型
type Follow struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	FollowerID  uint           `gorm:"not null;index;uniqueIndex:uk_follower_following" json:"follower_id"`  // 关注者ID
	FollowingID uint           `gorm:"not null;index;uniqueIndex:uk_follower_following" json:"following_id"` // 被关注者ID
	CreatedAt   time.Time      `json:"created_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
