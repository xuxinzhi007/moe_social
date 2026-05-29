package llmbiz_test

import (
	"context"
	"testing"

	llmv1 "backend/api/llm/v1"
	llmbiz "backend/internal/biz/llm"
	llmdata "backend/internal/data/llm"
	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func openMemoryDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skip("sqlite in-memory test requires CGO")
	}
	if err := db.AutoMigrate(
		&model.UserMemory{},
		&model.UserMemoryProfileCache{},
		&model.UserMemoryEmbedding{},
		&model.UserMemoryRelation{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestUpsertUserMemoryCreatesRow(t *testing.T) {
	db := openMemoryDB(t)
	resp, err := llmbiz.UpsertUserMemory(context.Background(), llmdata.NewStore(db), &llmv1.UpsertUserMemoryReq{
		UserId: "1",
		Key:    "user_name",
		Value:  "小萌",
		Source: "manual_test",
	}, llmbiz.MemoryWriteOptions{})
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if resp.GetMemory().GetValue() != "小萌" {
		t.Fatalf("unexpected value %q", resp.GetMemory().GetValue())
	}
}

func TestUpsertUserMemoryRejectsTechnicalKey(t *testing.T) {
	db := openMemoryDB(t)
	_, err := llmbiz.UpsertUserMemory(context.Background(), llmdata.NewStore(db), &llmv1.UpsertUserMemoryReq{
		UserId: "1",
		Key:    "device_info:foo",
		Value:  "bar",
		Source: "device_sync",
	}, llmbiz.MemoryWriteOptions{})
	if err == nil {
		t.Fatal("expected technical key rejection")
	}
}
