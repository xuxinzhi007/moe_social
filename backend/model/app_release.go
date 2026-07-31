package model

import (
	"time"

	"gorm.io/gorm"
)

const (
	// AppReleasePlatformAndroid 当前一期仅支持 Android 侧载更新。
	AppReleasePlatformAndroid = "android"
)

// AppRelease 管理台配置的 App 版本（每平台至多一条生效配置，按 platform 唯一）。
type AppRelease struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	Platform    string         `gorm:"size:32;not null;uniqueIndex" json:"platform"`
	VersionName string         `gorm:"size:64;not null" json:"version_name"`
	VersionCode int64          `gorm:"not null;index" json:"version_code"`
	ApkURL      string         `gorm:"size:1024;not null" json:"apk_url"`
	Changelog   string         `gorm:"type:text" json:"changelog"`
	ForceUpdate bool           `gorm:"not null;default:false" json:"force_update"`
	Enabled     bool           `gorm:"not null;default:true;index" json:"enabled"`
	UpdatedBy   uint           `gorm:"index" json:"updated_by"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName 表名。
func (AppRelease) TableName() string {
	return "app_releases"
}
