package model

import "time"

// AdminAuditLog Moe Admin 操作审计日志。
type AdminAuditLog struct {
	ID         uint      `gorm:"primarykey" json:"id"`
	AdminID    uint      `gorm:"not null;index" json:"admin_id"`
	AdminName  string    `gorm:"size:50" json:"admin_name"`
	Action     string    `gorm:"size:32;not null;index" json:"action"`
	Resource   string    `gorm:"size:32;not null;index" json:"resource"`
	ResourceID string    `gorm:"size:64;index" json:"resource_id"`
	Detail     string    `gorm:"type:text" json:"detail"`
	IP         string    `gorm:"size:64" json:"ip"`
	CreatedAt  time.Time `gorm:"index" json:"created_at"`
}
