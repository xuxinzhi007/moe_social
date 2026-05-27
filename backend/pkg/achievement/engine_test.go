//go:build cgo

package achievement

import (
	"testing"
	"time"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)
func TestApplyEventWelcomeAndFirstPost(t *testing.T) {
	db := openTestDB(t)
	seedDefinitions(t, db)

	engine := NewEngine(db)
	tx := db.Begin()

	uid := uint(1)
	unlocks, err := engine.ApplyEvent(tx, uid, Event{Type: EventUserInitialized})
	if err != nil {
		t.Fatalf("init: %v", err)
	}
	if len(unlocks) != 1 || unlocks[0].BadgeID != "welcome_aboard" {
		t.Fatalf("welcome unlock: %+v", unlocks)
	}

	unlocks, err = engine.ApplyEvent(tx, uid, Event{
		Type:       EventPostCreated,
		ImageCount: 1,
		HasTopic:   true,
		ContentLen: 10,
		Hour:       10,
	})
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	_ = tx.Commit()

	var progress model.UserAchievementProgress
	if err := db.Where("user_id = ? AND badge_id = ?", uid, "first_post").First(&progress).Error; err != nil {
		t.Fatalf("first_post progress: %v", err)
	}
	if progress.UnlockedAt == nil {
		t.Fatal("expected first_post unlocked")
	}
}

func openTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(
		&model.AchievementDefinition{},
		&model.UserAchievementProgress{},
		&model.UserDailyActivity{},
		&model.UserWeeklyActivity{},
		&model.UserLevel{},
		&model.ExpLog{},
		&model.Follow{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func seedDefinitions(t *testing.T, db *gorm.DB) {
	t.Helper()
	defs := []model.AchievementDefinition{
		{ID: "welcome_aboard", Name: "初来乍到", RuleType: model.RuleTypeOnce, RequiredCount: 1, ExpReward: 20, Enabled: true, SortOrder: 1},
		{ID: "first_post", Name: "初出茅庐", RuleType: model.RuleTypeOnce, RequiredCount: 1, ExpReward: 20, Enabled: true, SortOrder: 2},
		{ID: "photographer", Name: "摄影师", RuleType: model.RuleTypeCounter, RequiredCount: 10, ExpReward: 50, Enabled: true, SortOrder: 3},
	}
	for _, d := range defs {
		if err := db.Create(&d).Error; err != nil {
			t.Fatalf("seed def: %v", err)
		}
	}
	_ = time.Now()
}
