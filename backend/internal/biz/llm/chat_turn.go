package llmbiz

import (
	"context"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// RecordChatTurn 持久化 LLM 会话轮次。
func RecordChatTurn(ctx context.Context, st MemoryStore, in *moe.RecordLlmChatTurnReq) (*moe.RecordLlmChatTurnResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil || in.GetUserId() == 0 {
		return &moe.RecordLlmChatTurnResp{Ok: false}, nil
	}
	sessionID := strings.TrimSpace(in.GetSessionId())
	if sessionID == "" {
		return &moe.RecordLlmChatTurnResp{Ok: false}, nil
	}
	role := strings.TrimSpace(in.GetRole())
	if role == "" {
		role = "user"
	}
	now := time.Now()
	var sess model.AiChatSession
	err := db.WithContext(ctx).Where("user_id = ? AND session_id = ?", in.GetUserId(), sessionID).First(&sess).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			sess = model.AiChatSession{
				UserID:    uint(in.GetUserId()),
				SessionID: sessionID,
				Model:     strings.TrimSpace(in.GetModel()),
				CreatedAt: now,
				UpdatedAt: now,
			}
			if createErr := db.WithContext(ctx).Create(&sess).Error; createErr != nil {
				return &moe.RecordLlmChatTurnResp{Ok: false}, nil
			}
		} else {
			return &moe.RecordLlmChatTurnResp{Ok: false}, nil
		}
	} else {
		_ = db.WithContext(ctx).Model(&sess).Updates(map[string]any{
			"model":      strings.TrimSpace(in.GetModel()),
			"updated_at": now,
		}).Error
	}
	msg := model.AiChatMessage{
		UserID:      uint(in.GetUserId()),
		SessionID:   sessionID,
		SourceMsgID: strings.TrimSpace(in.GetSourceMsgId()),
		Role:        role,
		Content:     strings.TrimSpace(in.GetContent()),
		Model:       strings.TrimSpace(in.GetModel()),
		CreatedAt:   now,
	}
	if err := db.WithContext(ctx).Create(&msg).Error; err != nil {
		return &moe.RecordLlmChatTurnResp{Ok: false}, nil
	}
	return &moe.RecordLlmChatTurnResp{Ok: true}, nil
}
