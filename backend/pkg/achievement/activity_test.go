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
	// bumpDailyActivity 末尾会调 syncWeeklyActivity 写周表，所以两张表都必须建；
	// 只建日表的话用例会死在 "no such table: user_weekly_activity" 上。
	if err := db.AutoMigrate(&model.UserDailyActivity{}, &model.UserWeeklyActivity{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	uid := uint(1)
	date := todayDate(time.Now())
	existing := model.UserDailyActivity{
		UserID: uid,
		// 必须走 activityStorageDate：production 的 loadOrInitDailyActivity 写入的是 UTC 零点
		// （activity.go:115 的 dates[0]），直接存 todayDate 会带上 +08:00 偏移，
		// 后面 findDailyActivity 的 DATE(activity_date) 与本用例末尾的断言查询都匹配不到。
		ActivityDate: activityStorageDate(date),
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
