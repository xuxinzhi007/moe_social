package adminbiz_test

import (
	"context"
	"testing"

	adminbiz "backend/internal/biz/admin"
	admindata "backend/internal/data/admin"
	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func openAdminListDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skip("sqlite in-memory test requires CGO")
	}
	if err := db.AutoMigrate(&model.User{}, &model.AchievementDefinition{}, &model.AdminMenu{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestListUsersKeyword(t *testing.T) {
	db := openAdminListDB(t)
	rows := []model.User{
		{Username: "alice", Email: "alice@example.com", MoeNo: "M1001"},
		{Username: "bob", Email: "bob@example.com", MoeNo: "M1002"},
	}
	for i := range rows {
		if err := db.Create(&rows[i]).Error; err != nil {
			t.Fatal(err)
		}
	}
	users, total, err := adminbiz.ListUsers(context.Background(), admindata.NewStore(db), adminbiz.UserPage{
		Page: 1, PageSize: 10, Keyword: "alice",
	})
	if err != nil {
		t.Fatalf("list users: %v", err)
	}
	if total != 1 || len(users) != 1 {
		t.Fatalf("expected 1 user, got total=%d len=%d", total, len(users))
	}
	if users[0].GetUsername() != "alice" {
		t.Fatalf("unexpected username %q", users[0].GetUsername())
	}
}

func TestListAchievementsCategory(t *testing.T) {
	db := openAdminListDB(t)
	rows := []model.AchievementDefinition{
		{ID: "ach_a", Name: "A", Category: "social", SortOrder: 1},
		{ID: "ach_b", Name: "B", Category: "growth", SortOrder: 2},
	}
	for i := range rows {
		if err := db.Create(&rows[i]).Error; err != nil {
			t.Fatal(err)
		}
	}
	items, total, err := adminbiz.ListAchievements(context.Background(), admindata.NewStore(db), adminbiz.AchievementPage{
		Page: 1, PageSize: 10, Category: "social",
	})
	if err != nil {
		t.Fatalf("list achievements: %v", err)
	}
	if total != 1 || len(items) != 1 || items[0].GetId() != "ach_a" {
		t.Fatalf("unexpected achievements total=%d len=%d", total, len(items))
	}
}

func TestListMenusOrder(t *testing.T) {
	db := openAdminListDB(t)
	rows := []model.AdminMenu{
		{Key: "b", Label: "B", SortOrder: 20, Enabled: true},
		{Key: "a", Label: "A", SortOrder: 10, Enabled: true},
	}
	for i := range rows {
		if err := db.Create(&rows[i]).Error; err != nil {
			t.Fatal(err)
		}
	}
	items, err := adminbiz.ListMenus(context.Background(), admindata.NewStore(db))
	if err != nil {
		t.Fatalf("list menus: %v", err)
	}
	if len(items) != 2 || items[0].GetKey() != "a" {
		t.Fatalf("expected menu a first, got %v", items)
	}
}
