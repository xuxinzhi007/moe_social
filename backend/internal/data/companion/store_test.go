package companiondata

import (
	"context"
	"errors"
	"testing"
	"time"

	"backend/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestAppendAssistantReplyWithMemoryJobIsAtomic(t *testing.T) {
	db := newCompanionTestDB(t)
	if err := db.AutoMigrate(&model.CompanionChatLog{}, &model.CompanionMemoryExtractionJob{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}
	st := &store{db: db}
	userLog := &model.CompanionChatLog{UserID: 7, Role: "user", Content: "我喜欢青提"}
	if err := st.AppendChatLog(context.Background(), userLog); err != nil {
		t.Fatalf("AppendChatLog() error = %v", err)
	}

	reply := &model.CompanionChatLog{UserID: 7, Role: "assistant", Content: "记住了"}
	job := &model.CompanionMemoryExtractionJob{UserChatLogID: userLog.ID}
	if err := st.AppendAssistantReplyWithMemoryJob(context.Background(), reply, job); err != nil {
		t.Fatalf("AppendAssistantReplyWithMemoryJob() error = %v", err)
	}
	if reply.ID == 0 || job.AssistantChatLogID != reply.ID ||
		job.Status != model.CompanionMemoryExtractionQueued {
		t.Fatalf("reply=%+v job=%+v, want assistant log and queued job linked", reply, job)
	}

	secondReply := &model.CompanionChatLog{UserID: 7, Role: "assistant", Content: "重复回合"}
	if err := st.AppendAssistantReplyWithMemoryJob(
		context.Background(),
		secondReply,
		&model.CompanionMemoryExtractionJob{UserChatLogID: userLog.ID},
	); err == nil {
		t.Fatal("AppendAssistantReplyWithMemoryJob() error = nil, want duplicate turn rejected")
	}

	var chatLogCount, jobCount int64
	if err := db.Model(&model.CompanionChatLog{}).Count(&chatLogCount).Error; err != nil {
		t.Fatalf("count chat logs: %v", err)
	}
	if err := db.Model(&model.CompanionMemoryExtractionJob{}).Count(&jobCount).Error; err != nil {
		t.Fatalf("count jobs: %v", err)
	}
	if chatLogCount != 2 || jobCount != 1 {
		t.Fatalf("chat logs=%d jobs=%d, want 2 and 1 after rollback", chatLogCount, jobCount)
	}
}

func TestClaimNextMemoryExtractionJobReclaimsExpiredLease(t *testing.T) {
	db := newCompanionTestDB(t)
	if err := db.AutoMigrate(&model.CompanionMemoryExtractionJob{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}
	st := &store{db: db}
	now := time.Now()
	job := &model.CompanionMemoryExtractionJob{
		UserID:             7,
		UserChatLogID:      1,
		AssistantChatLogID: 2,
		Status:             model.CompanionMemoryExtractionQueued,
		NextAttemptAt:      now.Add(-time.Second),
	}
	if err := db.Create(job).Error; err != nil {
		t.Fatalf("create job: %v", err)
	}

	first, err := st.ClaimNextMemoryExtractionJob(context.Background(), now, now.Add(time.Minute))
	if err != nil {
		t.Fatalf("first claim: %v", err)
	}
	if first == nil || first.AttemptCount != 1 || first.Status != model.CompanionMemoryExtractionRunning {
		t.Fatalf("first claim=%+v, want running attempt 1", first)
	}
	second, err := st.ClaimNextMemoryExtractionJob(context.Background(), now, now.Add(time.Minute))
	if err != nil {
		t.Fatalf("second claim: %v", err)
	}
	if second != nil {
		t.Fatalf("second claim=%+v, want no active lease reclaimed", second)
	}

	expiredAt := now.Add(-time.Second)
	if err := db.Model(&model.CompanionMemoryExtractionJob{}).
		Where("id = ?", job.ID).
		Update("lease_until", expiredAt).Error; err != nil {
		t.Fatalf("expire job lease: %v", err)
	}
	reclaimed, err := st.ClaimNextMemoryExtractionJob(context.Background(), now, now.Add(time.Minute))
	if err != nil {
		t.Fatalf("reclaim expired job: %v", err)
	}
	if reclaimed == nil || reclaimed.AttemptCount != 2 {
		t.Fatalf("reclaimed job=%+v, want attempt 2", reclaimed)
	}
	if err := st.CompleteMemoryExtractionJob(context.Background(), job.ID, 1, now); !errors.Is(
		err,
		gorm.ErrRecordNotFound,
	) {
		t.Fatalf("stale completion error = %v, want record not found", err)
	}
	if err := st.RetryMemoryExtractionJob(
		context.Background(),
		job.ID,
		1,
		now.Add(time.Minute),
		"stale worker",
	); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("stale retry error = %v, want record not found", err)
	}
	if err := st.CompleteMemoryExtractionJob(context.Background(), job.ID, reclaimed.AttemptCount, now); err != nil {
		t.Fatalf("complete reclaimed job: %v", err)
	}
}

func TestCreateMemoryConflictIsIdempotent(t *testing.T) {
	db := newCompanionTestDB(t)
	if err := db.AutoMigrate(&model.CompanionMemoryConflict{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}
	st := &store{db: db}
	conflict := &model.CompanionMemoryConflict{
		UserID:           7,
		MemoryID:         9,
		MemoryType:       "preference",
		MemoryKey:        "favorite_fruit",
		DedupeKey:        "memory_conflict:9:likes-grapes",
		CandidateContent: "用户喜欢青提",
		Status:           "pending",
	}

	for range 2 {
		if err := st.CreateMemoryConflict(context.Background(), conflict); err != nil {
			t.Fatalf("CreateMemoryConflict() error = %v, want duplicate to be ignored", err)
		}
	}
	var count int64
	if err := db.Model(&model.CompanionMemoryConflict{}).Count(&count).Error; err != nil {
		t.Fatalf("count memory conflicts: %v", err)
	}
	if count != 1 {
		t.Fatalf("memory conflict count = %d, want 1", count)
	}
}

func newCompanionTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	return db
}
