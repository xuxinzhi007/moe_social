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

func openTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skip("sqlite in-memory test requires CGO")
	}
	if err := db.AutoMigrate(&model.Gift{}, &model.GiftRecord{}, &model.GiftPurchaseOrder{}, &model.UserGiftStock{}, &model.TopicTag{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestBootstrapTopicTagsEmptyTable(t *testing.T) {
	db := openTestDB(t)
	created, err := adminbiz.BootstrapTopicTags(context.Background(), admindata.NewStore(db))
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	if created != 6 {
		t.Fatalf("expected 6 created, got %d", created)
	}
	var count int64
	if err := db.Model(&model.TopicTag{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 6 {
		t.Fatalf("expected 6 rows, got %d", count)
	}
}

func TestDeduplicateGiftsByName(t *testing.T) {
	db := openTestDB(t)
	rows := []model.Gift{
		{Name: "爱心", Price: 1, Category: "emotion", SortOrder: 10},
		{Name: "点赞", Price: 1, Category: "emotion", SortOrder: 20},
		{Name: "爱心", Price: 1, Category: "emotion", SortOrder: 10},
	}
	for i := range rows {
		if err := db.Create(&rows[i]).Error; err != nil {
			t.Fatal(err)
		}
	}
	removed, err := adminbiz.DeduplicateGiftsByName(context.Background(), admindata.NewStore(db))
	if err != nil {
		t.Fatalf("dedupe: %v", err)
	}
	if removed != 1 {
		t.Fatalf("expected 1 removed, got %d", removed)
	}
	var count int64
	if err := db.Model(&model.Gift{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 2 {
		t.Fatalf("expected 2 gifts left, got %d", count)
	}
}
