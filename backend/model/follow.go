package model

import (
	"time"

	"gorm.io/gorm"
)

// Follow 关注关系模型
type Follow struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	FollowerID  uint           `gorm:"not null;index:idx_follower_following,unique:idx_follower_following" json:"follower_id"`  // 关注者ID
	FollowingID uint           `gorm:"not null;index:idx_following_follower,unique:idx_follower_following" json:"following_id"` // 被关注者ID
	CreatedAt   time.Time      `json:"created_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Follower  User `gorm:"foreignKey:FollowerID" json:"follower"`   // 关注者
	Following User `gorm:"foreignKey:FollowingID" json:"following"` // 被关注者
}
