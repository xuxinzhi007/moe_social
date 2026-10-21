package aidata

import (
	"context"
	"testing"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestGetUserDisplayNameUsesUsernameOnly(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	if err := db.AutoMigrate(&model.User{}); err != nil {
		t.Fatalf("migrate user: %v", err)
	}
	user := model.User{
		Username:   "xinzhixu",
		MoeNo:      "1000000001",
		Password:   "secret",
		Email:      "xinzhixu@example.com",
		FeishuName: "xinzhi.xu",
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	got := NewStore(db).GetUserDisplayName(context.Background(), user.ID)
	if got != "xinzhixu" {
		t.Fatalf("display name = %q, want username only", got)
	}
}
