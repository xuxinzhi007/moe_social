package utils

import (
	"strings"
	"testing"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestWriteAdminAuditLogNilDB(t *testing.T) {
	if err := WriteAdminAuditLog(nil, AdminAuditEntry{
		AdminID:   1,
		AdminName: "admin",
		Action:    "update",
		Resource:  "user",
	}); err != nil {
		t.Fatalf("nil db should no-op: %v", err)
	}
}

func TestWriteAdminAuditLog(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		if strings.Contains(err.Error(), "CGO_ENABLED=0") || strings.Contains(err.Error(), "cgo") {
			t.Skip("sqlite in-memory test requires CGO")
		}
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(&model.AdminAuditLog{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	err = WriteAdminAuditLog(db, AdminAuditEntry{
		AdminID:    1,
		AdminName:  "admin",
		Action:     "update",
		Resource:   "user",
		ResourceID: "42",
		Detail:     "更新 App 用户",
		IP:         "127.0.0.1",
	})
	if err != nil {
		t.Fatalf("write audit: %v", err)
	}

	var count int64
	if err := db.Model(&model.AdminAuditLog{}).Count(&count).Error; err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected 1 audit row, got %d", count)
	}
}
