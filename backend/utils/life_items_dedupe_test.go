package utils

import (
	"testing"

	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// createLegacyLifeTables 模拟修复前的旧库：life_items 没有 idx_life_items_name 唯一索引，
// 正是「每次启动 +6 行」污染出来的表形态。life_inventory 按模型建唯一索引 (user_id, item_id)。
func createLegacyLifeTables(t *testing.T, db *gorm.DB) {
	t.Helper()
	if err := db.Exec(`CREATE TABLE life_items (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		icon TEXT DEFAULT '',
		description TEXT DEFAULT '',
		item_type TEXT NOT NULL,
		effect_key TEXT NOT NULL,
		effect_value REAL NOT NULL DEFAULT 10,
		duration_ticks INTEGER NOT NULL DEFAULT 0,
		created_at DATETIME,
		updated_at DATETIME
	)`).Error; err != nil {
		t.Fatalf("create legacy life_items: %v", err)
	}
	if err := db.Exec(`CREATE TABLE life_inventory (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id TEXT NOT NULL,
		item_id INTEGER NOT NULL,
		quantity INTEGER NOT NULL DEFAULT 0,
		created_at DATETIME,
		updated_at DATETIME,
		UNIQUE(user_id, item_id)
	)`).Error; err != nil {
		t.Fatalf("create legacy life_inventory: %v", err)
	}
}

// seedLegacyDupRows 模拟 3 次启动的污染：同名「普通食物」3 行（id 1/2/3），另有一个无重复的名字。
// 库存挂法覆盖三种归并形态：
//   - u1 在 canon(1) 与 dup(2) 都有行 → 数量相加
//   - u2 只在 dup(2) 有行 → 改指 canon
//   - u3 在两个 dup(2/3) 都有行 → 先改指再累加
func seedLegacyDupRows(t *testing.T, db *gorm.DB) {
	t.Helper()
	items := []*model.LifeItem{
		{Name: "普通食物", ItemType: "food", EffectKey: "hunger", EffectValue: 20},
		{Name: "普通食物", ItemType: "food", EffectKey: "hunger", EffectValue: 20},
		{Name: "普通食物", ItemType: "food", EffectKey: "hunger", EffectValue: 20},
		{Name: "经验书", ItemType: "food", EffectKey: "experience", EffectValue: 50},
	}
	if err := db.Create(&items).Error; err != nil {
		t.Fatalf("seed legacy items: %v", err)
	}
	invs := []*model.LifeInventory{
		{UserID: "u1", ItemID: items[0].ID, Quantity: 5},
		{UserID: "u1", ItemID: items[1].ID, Quantity: 3},
		{UserID: "u2", ItemID: items[1].ID, Quantity: 2},
		{UserID: "u3", ItemID: items[1].ID, Quantity: 1},
		{UserID: "u3", ItemID: items[2].ID, Quantity: 4},
	}
	if err := db.Create(&invs).Error; err != nil {
		t.Fatalf("seed legacy inventory: %v", err)
	}
}

func inventoryOf(t *testing.T, db *gorm.DB, userID string) map[uint]int {
	t.Helper()
	var rows []model.LifeInventory
	if err := db.Where("user_id = ?", userID).Find(&rows).Error; err != nil {
		t.Fatalf("query inventory for %s: %v", userID, err)
	}
	out := map[uint]int{}
	for _, r := range rows {
		out[r.ItemID] = r.Quantity
	}
	return out
}

func TestDedupeLifeItemsByNameMergesAndReroutes(t *testing.T) {
	db := testMigrateDB(t)
	createLegacyLifeTables(t, db)
	seedLegacyDupRows(t, db)

	if err := dedupeLifeItemsByName(db); err != nil {
		t.Fatalf("dedupe: %v", err)
	}

	var survivors []model.LifeItem
	if err := db.Where("name = ?", "普通食物").Find(&survivors).Error; err != nil {
		t.Fatalf("query survivors: %v", err)
	}
	if len(survivors) != 1 {
		t.Fatalf("普通食物 should survive exactly once, got %d rows", len(survivors))
	}
	canon := survivors[0].ID
	if canon != 1 {
		t.Fatalf("canonical row should keep smallest id 1, got %d", canon)
	}

	u1 := inventoryOf(t, db, "u1")
	if got := u1[canon]; got != 8 {
		t.Errorf("u1 canonical quantity = %d, want 8 (5+3 merged)", got)
	}
	u2 := inventoryOf(t, db, "u2")
	if got := u2[canon]; got != 2 {
		t.Errorf("u2 canonical quantity = %d, want 2 (rerouted)", got)
	}
	u3 := inventoryOf(t, db, "u3")
	if got := u3[canon]; got != 5 {
		t.Errorf("u3 canonical quantity = %d, want 5 (1+4 from two dups)", got)
	}

	var dangling int64
	if err := db.Model(&model.LifeInventory{}).
		Where("item_id IN ?", []uint{2, 3}).Count(&dangling).Error; err != nil {
		t.Fatalf("count dangling inventory: %v", err)
	}
	if dangling != 0 {
		t.Errorf("found %d inventory rows still pointing at deleted items", dangling)
	}

	// 其他名字不受影响
	var other int64
	if err := db.Model(&model.LifeItem{}).Where("name = ?", "经验书").Count(&other).Error; err != nil {
		t.Fatalf("count 经验书: %v", err)
	}
	if other != 1 {
		t.Errorf("经验书 rows = %d, want 1", other)
	}

	// 幂等：再跑一次应零改动
	var before int64
	if err := db.Model(&model.LifeItem{}).Count(&before).Error; err != nil {
		t.Fatalf("count items: %v", err)
	}
	if err := dedupeLifeItemsByName(db); err != nil {
		t.Fatalf("dedupe second pass: %v", err)
	}
	var after int64
	if err := db.Model(&model.LifeItem{}).Count(&after).Error; err != nil {
		t.Fatalf("count items: %v", err)
	}
	if after != before {
		t.Errorf("second pass changed item count %d → %d, dedupe not idempotent", before, after)
	}
}

// TestDedupeViaRunAutoMigrate 走真实迁移入口：Force 重迁 life 两张表时，
// BeforeMigrate 先去重，随后 AutoMigrate 才能给 name 建上唯一索引。
func TestDedupeViaRunAutoMigrate(t *testing.T) {
	db := testMigrateDB(t)
	createLegacyLifeTables(t, db)
	seedLegacyDupRows(t, db)

	opts := MigrateOptions{Enabled: true, Models: []string{"life_items", "life_inventory"}, Force: true}
	if err := RunAutoMigrate(db, opts); err != nil {
		t.Fatalf("run auto migrate over polluted table: %v", err)
	}

	var n int64
	if err := db.Model(&model.LifeItem{}).Where("name = ?", "普通食物").Count(&n).Error; err != nil {
		t.Fatalf("count 普通食物: %v", err)
	}
	if n != 1 {
		t.Fatalf("普通食物 rows after migrate = %d, want 1", n)
	}

	// 唯一索引已生效：直接再插同名应被 DoNothing 拦下，行数不变。
	dup := &model.LifeItem{Name: "普通食物", ItemType: "food", EffectKey: "hunger", EffectValue: 20}
	if err := db.Clauses(clause.OnConflict{DoNothing: true}).Create(dup).Error; err != nil {
		t.Fatalf("seed insert after unique index: %v", err)
	}
	if err := db.Model(&model.LifeItem{}).Where("name = ?", "普通食物").Count(&n).Error; err != nil {
		t.Fatalf("count 普通食物: %v", err)
	}
	if n != 1 {
		t.Fatalf("DoNothing did not stop duplicate seed: %d rows", n)
	}
}
