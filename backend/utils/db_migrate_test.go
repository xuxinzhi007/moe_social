package utils

import (
	"strings"
	"testing"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"gorm.io/gorm/schema"
)

func TestComputeModelHashStable(t *testing.T) {
	db := testNamingDB()

	_, h1, err := computeModelHash(db, &model.User{})
	if err != nil {
		t.Fatalf("hash user: %v", err)
	}
	_, h2, err := computeModelHash(db, &model.User{})
	if err != nil {
		t.Fatalf("hash user again: %v", err)
	}
	if h1 != h2 {
		t.Fatalf("expected stable hash, got %q vs %q", h1, h2)
	}
	if len(h1) != 32 {
		t.Fatalf("expected 32-char hex hash, got len=%d", len(h1))
	}
}

func TestRunAutoMigrateSkipsUnchanged(t *testing.T) {
	db := testMigrateDB(t)

	opts := MigrateOptions{Enabled: true}
	if err := RunAutoMigrate(db, opts); err != nil {
		t.Fatalf("first migrate: %v", err)
	}

	if err := RunAutoMigrate(db, opts); err != nil {
		t.Fatalf("second migrate: %v", err)
	}

	var n int64
	if err := db.Model(&model.GormSchemaVersion{}).Count(&n).Error; err != nil {
		t.Fatalf("count schema versions: %v", err)
	}
	if n != int64(len(MigrateModelRegistry())) {
		t.Fatalf("expected %d schema version rows, got %d", len(MigrateModelRegistry()), n)
	}
}

func TestFilterMigrateEntries(t *testing.T) {
	got := filterMigrateEntries([]string{"users", "posts", "unknown"})
	if len(got) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(got))
	}
}

func testNamingDB() *gorm.DB {
	return &gorm.DB{
		Config: &gorm.Config{
			NamingStrategy: schema.NamingStrategy{},
		},
	}
}

func testMigrateDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		if strings.Contains(err.Error(), "CGO_ENABLED") {
			t.Skip("sqlite driver requires cgo on this platform")
		}
		t.Fatalf("open sqlite: %v", err)
	}
	return db
}
