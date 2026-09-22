package llmdata

import (
	"context"
	"errors"
	"fmt"
	"time"

	llmbiz "backend/internal/biz/llm"
	"backend/model"

	"gorm.io/gorm"
)

func (s *Store) ListChatSessions(
	ctx context.Context,
	userID uint,
	agentID string,
	limit int,
) ([]model.AiChatSession, error) {
	rows := []model.AiChatSession{}
	q := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if agentID != "" {
		q = q.Where("agent_id = ?", agentID)
	}
	err := q.Order("updated_at DESC, id DESC").Limit(limit).Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("list ai chat sessions for user %d: %w", userID, err)
	}
	return rows, nil
}

func (s *Store) ListChatMessages(
	ctx context.Context,
	userID uint,
	sessionID string,
	limit int,
) ([]model.AiChatMessage, error) {
	rows := []model.AiChatMessage{}
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND session_id = ?", userID, sessionID).
		Order("created_at ASC, id ASC").
		Limit(limit).
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("list ai chat messages for session %s: %w", sessionID, err)
	}
	return rows, nil
}

func (s *Store) UpsertChatSession(
	ctx context.Context,
	userID uint,
	input llmbiz.ChatSessionInput,
) (model.AiChatSession, error) {
	var row model.AiChatSession
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		err := tx.Where("user_id = ? AND session_id = ?", userID, input.SessionID).First(&row).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("load ai chat session %s: %w", input.SessionID, err)
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row = model.AiChatSession{UserID: userID, SessionID: input.SessionID}
		}
		if input.AgentID != "" {
			row.AgentID = input.AgentID
		}
		if input.Title != "" {
			row.Title = input.Title
		}
		if input.Model != "" {
			row.Model = input.Model
		}
		if err := tx.Save(&row).Error; err != nil {
			return fmt.Errorf("save ai chat session %s: %w", input.SessionID, err)
		}
		return nil
	})
	if err != nil {
		return model.AiChatSession{}, err
	}
	return row, nil
}

func (s *Store) DeleteChatSession(ctx context.Context, userID uint, sessionID string) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ? AND session_id = ?", userID, sessionID).
			Delete(&model.AiChatMessage{}).Error; err != nil {
			return fmt.Errorf("delete ai chat messages for session %s: %w", sessionID, err)
		}
		if err := tx.Where("user_id = ? AND session_id = ?", userID, sessionID).
			Delete(&model.AiChatSession{}).Error; err != nil {
			return fmt.Errorf("delete ai chat session %s: %w", sessionID, err)
		}
		return nil
	})
}

func (s *Store) UpsertChatMessage(
	ctx context.Context,
	userID uint,
	input llmbiz.ChatMessageInput,
) (model.AiChatMessage, error) {
	var row model.AiChatMessage
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := ensureChatSession(tx, userID, input); err != nil {
			return err
		}
		err := gorm.ErrRecordNotFound
		if input.SourceMsgID != "" {
			err = tx.Where("user_id = ? AND source_msg_id = ?", userID, input.SourceMsgID).
				First(&row).Error
		}
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("load ai chat message %s: %w", input.SourceMsgID, err)
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row = model.AiChatMessage{
				UserID:      userID,
				SessionID:   input.SessionID,
				SourceMsgID: input.SourceMsgID,
				CreatedAt:   input.CreatedAt,
			}
		}
		row.Role = input.Role
		row.Content = input.Content
		row.Model = input.Model
		if err := tx.Save(&row).Error; err != nil {
			return fmt.Errorf("save ai chat message %s: %w", input.SourceMsgID, err)
		}
		if err := tx.Model(&model.AiChatSession{}).
			Where("user_id = ? AND session_id = ?", userID, input.SessionID).
			Update("updated_at", latestTime(input.CreatedAt, time.Now())).Error; err != nil {
			return fmt.Errorf("touch ai chat session %s: %w", input.SessionID, err)
		}
		return nil
	})
	if err != nil {
		return model.AiChatMessage{}, err
	}
	return row, nil
}

func (s *Store) DeleteChatMessage(ctx context.Context, userID uint, sourceMsgID string) error {
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND source_msg_id = ?", userID, sourceMsgID).
		Delete(&model.AiChatMessage{}).Error
	if err != nil {
		return fmt.Errorf("delete ai chat message %s: %w", sourceMsgID, err)
	}
	return nil
}

func ensureChatSession(tx *gorm.DB, userID uint, input llmbiz.ChatMessageInput) error {
	var count int64
	if err := tx.Model(&model.AiChatSession{}).
		Where("user_id = ? AND session_id = ?", userID, input.SessionID).
		Count(&count).Error; err != nil {
		return fmt.Errorf("check ai chat session %s: %w", input.SessionID, err)
	}
	if count > 0 {
		return nil
	}
	row := model.AiChatSession{UserID: userID, SessionID: input.SessionID, Model: input.Model}
	if err := tx.Create(&row).Error; err != nil {
		return fmt.Errorf("create ai chat session %s: %w", input.SessionID, err)
	}
	return nil
}

func latestTime(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}
