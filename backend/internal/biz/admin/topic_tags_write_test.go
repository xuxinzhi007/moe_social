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
	// model.Gift.Name 带 uniqueIndex（与本函数同一个提交 8c701f61 引入），不先丢掉索引的话
	// 第二条同名礼物会被 UNIQUE 约束直接拒掉，用例根本走不到被测函数。
	// 去重针对的是「索引上线前就已经有重复行的老库」，夹具要还原的正是那个前提。
	if err := db.Migrator().DropIndex(&model.Gift{}, "Name"); err != nil {
		t.Fatalf("drop unique index on gifts.name: %v", err)
	}
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
