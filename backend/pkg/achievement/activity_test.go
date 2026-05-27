//go:build cgo

package achievement

import (
	"testing"
	"time"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestBumpDailyActivityRevivesSoftDeletedRow(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(&model.UserDailyActivity{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	uid := uint(1)
	date := todayDate(time.Now())
	existing := model.UserDailyActivity{
		UserID:       uid,
		ActivityDate: date,
		PostCount:    1,
		TaskScore:    1,
	}
	if err := db.Create(&existing).Error; err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := db.Delete(&existing).Error; err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	engine := NewEngine(db)
	tx := db.Begin()
	if err := engine.bumpDailyActivity(tx, uid, time.Now(), true, false, false); err != nil {
		t.Fatalf("bump: %v", err)
	}
	if err := tx.Commit().Error; err != nil {
		t.Fatalf("commit: %v", err)
	}

	var row model.UserDailyActivity
	if err := db.Where("user_id = ? AND activity_date = ?", uid, activityStorageDate(date)).
		First(&row).Error; err != nil {
		t.Fatalf("load row: %v", err)
	}
	if row.PostCount != 2 {
		t.Fatalf("post_count want 2 got %d", row.PostCount)
	}
	if row.TaskScore != 1 {
		t.Fatalf("task_score want 1 got %d", row.TaskScore)
	}
}
