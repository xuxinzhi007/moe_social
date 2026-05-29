package llmbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	llmv1 "backend/api/llm/v1"
	"backend/model"

	"gorm.io/gorm"
)

// SubmitUserMemoryFeedback 处理 accept/reject/correct 反馈。
func SubmitUserMemoryFeedback(ctx context.Context, st MemoryStore, in *llmv1.SubmitUserMemoryFeedbackReq) (*llmv1.SubmitUserMemoryFeedbackResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	if strings.TrimSpace(in.GetUserId()) == "" {
		return nil, ErrMemoryEmptyUserID
	}
	if strings.TrimSpace(in.GetKey()) == "" {
		return nil, ErrMemoryEmptyKey
	}
	feedbackType := strings.ToLower(strings.TrimSpace(in.GetFeedbackType()))
	if feedbackType != "accept" && feedbackType != "reject" && feedbackType != "correct" {
		return nil, errors.New("feedback_type必须是accept/reject/correct")
	}
	if feedbackType == "correct" && strings.TrimSpace(in.GetCorrectedValue()) == "" {
		return nil, errors.New("correct反馈必须提供corrected_value")
	}

	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrMemoryInvalidUser
	}

	var memory model.UserMemory
	if err := db.Where("user_id = ? AND `key` = ?", uint(userID), in.GetKey()).First(&memory).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemoryNotFound
		}
		return nil, err
	}

	oldValue := memory.Value
	reason := strings.TrimSpace(in.GetReason())

	switch feedbackType {
	case "accept":
		memory.Confidence = minFloat(memory.Confidence+0.08, 1)
		memory.Source = "feedback_accept"
	case "reject":
		memory.Confidence = maxFloat(memory.Confidence-0.2, 0.05)
		memory.Source = "feedback_reject"
	case "correct":
		memory.Value = strings.TrimSpace(in.GetCorrectedValue())
		memory.Confidence = maxFloat(memory.Confidence, 0.9)
		memory.Source = "manual_correct"
	}

	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&memory).Error; err != nil {
			return err
		}
		feedback := model.UserMemoryFeedback{
			UserID:       memory.UserID,
			Key:          memory.Key,
			FeedbackType: feedbackType,
			OldValue:     oldValue,
			NewValue:     memory.Value,
			Reason:       reason,
		}
		return tx.Create(&feedback).Error
	}); err != nil {
		return nil, err
	}

	go func() { _ = RebuildUserMemoryProfileCache(db, memory.UserID) }()

	return &llmv1.SubmitUserMemoryFeedbackResp{Memory: userMemoryToProto(memory)}, nil
}

func minFloat(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

func maxFloat(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}
