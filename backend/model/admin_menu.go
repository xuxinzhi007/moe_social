package model

import (
	"time"

	"gorm.io/gorm"
)

// AdminMenu Moe Admin 侧栏菜单配置（扁平存储，parent_key 关联分组）。
type AdminMenu struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	Key          string         `gorm:"uniqueIndex;size:64;not null" json:"key"`
	Kind         string         `gorm:"size:16;not null" json:"kind"` // item | group | link
	ParentKey    string         `gorm:"size:64;index" json:"parent_key"`
	Path         string         `gorm:"size:128" json:"path"`
	Label        string         `gorm:"size:64;not null" json:"label"`
	Icon         string         `gorm:"size:16" json:"icon"`
	Caption      string         `gorm:"size:128" json:"caption"`
	Status       string         `gorm:"size:16;default:planned" json:"status"` // ready | partial | planned
	AppDomain    string         `gorm:"size:64" json:"app_domain"`
	SortOrder    int            `gorm:"not null;default:0" json:"sort_order"`
	DefaultOpen  bool           `gorm:"not null;default:false" json:"default_open"`
	End          bool           `gorm:"not null;default:false" json:"end"`
	ExternalHref string         `gorm:"size:256" json:"external_href"`
	Enabled      bool           `gorm:"not null;default:true" json:"enabled"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}
