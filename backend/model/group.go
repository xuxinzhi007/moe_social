package model

import (
	"time"

	"gorm.io/gorm"
)

// Group 兴趣群组模型
type Group struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	Name        string         `gorm:"size:100;not null" json:"name"`        // 群组名称
	Description string         `gorm:"type:text" json:"description"`         // 群组描述
	Avatar      string         `gorm:"type:text" json:"avatar"`              // 群组头像
	Cover       string         `gorm:"type:text" json:"cover"`               // 群组封面
	CreatorID   uint           `gorm:"not null;index" json:"creator_id"`     // 创建者ID
	MemberCount int            `gorm:"default:0" json:"member_count"`        // 成员数量
	IsPublic    bool           `gorm:"default:true" json:"is_public"`        // 是否公开
	Status      string         `gorm:"size:20;default:active" json:"status"` // 状态：active/inactive
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Creator  User         `gorm:"foreignKey:CreatorID" json:"-"`  // 创建者关联
	Members  []GroupMember `gorm:"foreignKey:GroupID" json:"-"`  // 成员关联
	Posts    []GroupPost   `gorm:"foreignKey:GroupID" json:"-"`  // 群组帖子关联
}

// GroupMember 群组成员关系模型
type GroupMember struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	GroupID   uint           `gorm:"not null;index" json:"group_id"`   // 群组ID
	UserID    uint           `gorm:"not null;index" json:"user_id"`    // 用户ID
	Role      string         `gorm:"size:20;default:member" json:"role"` // 角色：admin/member
	JoinAt    time.Time      `json:"join_at"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Group Group `gorm:"foreignKey:GroupID" json:"-"`
	User  User  `gorm:"foreignKey:UserID" json:"-"`
}

// GroupPost 群组帖子模型
type GroupPost struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	GroupID   uint           `gorm:"not null;index" json:"group_id"`   // 群组ID
	PostID    uint           `gorm:"not null;index" json:"post_id"`    // 帖子ID
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Group Group `gorm:"foreignKey:GroupID" json:"-"`
	Post  Post  `gorm:"foreignKey:PostID" json:"-"`
}
