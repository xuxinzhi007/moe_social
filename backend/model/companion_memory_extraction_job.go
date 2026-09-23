package model

import "time"

const (
	// CompanionMemoryExtractionQueued marks a task that is ready to be claimed.
	CompanionMemoryExtractionQueued = "queued"
	// CompanionMemoryExtractionRunning marks a task with an active lease.
	CompanionMemoryExtractionRunning = "running"
	// CompanionMemoryExtractionRetrying marks a task waiting for its next attempt.
	CompanionMemoryExtractionRetrying = "retrying"
	// CompanionMemoryExtractionCompleted marks a task that finished successfully.
	CompanionMemoryExtractionCompleted = "completed"
)

// CompanionMemoryExtractionJob tracks durable extraction work by chat-log IDs.
type CompanionMemoryExtractionJob struct {
	ID                 uint       `gorm:"primarykey" json:"id"`
	UserID             uint       `gorm:"not null;uniqueIndex:idx_comp_mem_job_turn,priority:1;index" json:"user_id"`
	UserChatLogID      uint       `gorm:"not null;uniqueIndex:idx_comp_mem_job_turn,priority:2" json:"user_chat_log_id"`
	AssistantChatLogID uint       `gorm:"not null" json:"assistant_chat_log_id"`
	Status             string     `gorm:"size:16;not null;index:idx_comp_mem_job_ready,priority:1" json:"status"`
	AttemptCount       int        `gorm:"not null;default:0" json:"attempt_count"`
	NextAttemptAt      time.Time  `gorm:"not null;index:idx_comp_mem_job_ready,priority:2" json:"next_attempt_at"`
	LeaseUntil         *time.Time `gorm:"index" json:"lease_until,omitempty"`
	LastError          string     `gorm:"type:text" json:"last_error,omitempty"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// TableName returns the database table name for CompanionMemoryExtractionJob.
func (CompanionMemoryExtractionJob) TableName() string {
	return "companion_memory_extraction_jobs"
}
