package tools

import (
	"errors"
	"testing"
	"time"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestReservePostQuotaTreatsZeroAsUnlimitedAndCanReleaseFailedPost(t *testing.T) {
	db := newPostQuotaTestDB(t)
	resetDate := time.Now().UTC().Truncate(24 * time.Hour)
	runtime := model.MoeAgentRuntime{
		AgentKey:       "test_bot",
		Enabled:        true,
		PostQuotaDaily: 0,
		PostsToday:     7,
		QuotaResetDate: &resetDate,
	}
	if err := db.Create(&runtime).Error; err != nil {
		t.Fatalf("create runtime: %v", err)
	}

	release, err := reservePostQuota(db, runtime.AgentKey)
	if err != nil {
		t.Fatalf("reservePostQuota() error = %v", err)
	}
	var saved model.MoeAgentRuntime
	if err := db.First(&saved, runtime.ID).Error; err != nil {
		t.Fatalf("load runtime: %v", err)
	}
	if saved.PostsToday != 8 {
		t.Fatalf("PostsToday after reserve = %d, want 8", saved.PostsToday)
	}

	if err := release(); err != nil {
		t.Fatalf("release reservation: %v", err)
	}
	if err := db.First(&saved, runtime.ID).Error; err != nil {
		t.Fatalf("reload runtime: %v", err)
	}
	if saved.PostsToday != 7 {
		t.Fatalf("PostsToday after release = %d, want 7", saved.PostsToday)
	}
}

func TestReservePostQuotaEnforcesPositiveQuotaAndResetsNewDay(t *testing.T) {
	db := newPostQuotaTestDB(t)
	yesterday := time.Now().UTC().AddDate(0, 0, -1).Truncate(24 * time.Hour)
	runtime := model.MoeAgentRuntime{
		AgentKey:       "test_bot",
		Enabled:        true,
		PostQuotaDaily: 1,
		PostsToday:     1,
		QuotaResetDate: &yesterday,
	}
	if err := db.Create(&runtime).Error; err != nil {
		t.Fatalf("create runtime: %v", err)
	}

	release, err := reservePostQuota(db, runtime.AgentKey)
	if err != nil {
		t.Fatalf("reservePostQuota() after day reset error = %v", err)
	}
	if err := db.First(&runtime, runtime.ID).Error; err != nil {
		t.Fatalf("load runtime: %v", err)
	}
	if runtime.PostsToday != 1 {
		t.Fatalf("PostsToday after reset and reserve = %d, want 1", runtime.PostsToday)
	}

	if _, err := reservePostQuota(db, runtime.AgentKey); !errors.Is(err, errQuotaExceeded) {
		t.Fatalf("second reserve error = %v, want errQuotaExceeded", err)
	}
	if err := release(); err != nil {
		t.Fatalf("release reservation: %v", err)
	}
}

func newPostQuotaTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite test database: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("get sqlite connection: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() {
		_ = sqlDB.Close()
	})
	if err := db.AutoMigrate(&model.MoeAgentRuntime{}); err != nil {
		t.Fatalf("migrate runtime table: %v", err)
	}
	return db
}
