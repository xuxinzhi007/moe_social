package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

// AdminAuditEntry 写入审计日志的参数。
type AdminAuditEntry struct {
	AdminID    uint
	AdminName  string
	Action     string
	Resource   string
	ResourceID string
	Detail     string
	IP         string
}

// WriteAdminAuditLog 记录 Moe Admin 操作审计。
func WriteAdminAuditLog(db *gorm.DB, entry AdminAuditEntry) error {
	if db == nil {
		return nil
	}
	row := model.AdminAuditLog{
		AdminID:    entry.AdminID,
		AdminName:  entry.AdminName,
		Action:     entry.Action,
		Resource:   entry.Resource,
		ResourceID: entry.ResourceID,
		Detail:     entry.Detail,
		IP:         entry.IP,
	}
	return db.Create(&row).Error
}
