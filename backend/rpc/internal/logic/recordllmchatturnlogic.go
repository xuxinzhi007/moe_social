package logic

import (
	"context"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type RecordLlmChatTurnLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRecordLlmChatTurnLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RecordLlmChatTurnLogic {
	return &RecordLlmChatTurnLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RecordLlmChatTurnLogic) RecordLlmChatTurn(in *super.RecordLlmChatTurnReq) (*super.RecordLlmChatTurnResp, error) {
	if l.svcCtx.DB == nil || in.GetUserId() == 0 {
		return &super.RecordLlmChatTurnResp{Ok: false}, nil
	}
	sessionID := strings.TrimSpace(in.GetSessionId())
	if sessionID == "" {
		return &super.RecordLlmChatTurnResp{Ok: false}, nil
	}
	role := strings.TrimSpace(in.GetRole())
	if role == "" {
		role = "user"
	}
	now := time.Now()
	var sess model.AiChatSession
	err := l.svcCtx.DB.Where("user_id = ? AND session_id = ?", in.GetUserId(), sessionID).First(&sess).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			sess = model.AiChatSession{
				UserID:    uint(in.GetUserId()),
				SessionID: sessionID,
				Model:     strings.TrimSpace(in.GetModel()),
				CreatedAt: now,
				UpdatedAt: now,
			}
			if createErr := l.svcCtx.DB.Create(&sess).Error; createErr != nil {
				return &super.RecordLlmChatTurnResp{Ok: false}, nil
			}
		} else {
			return &super.RecordLlmChatTurnResp{Ok: false}, nil
		}
	} else {
		_ = l.svcCtx.DB.Model(&sess).Updates(map[string]any{
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
	if err := l.svcCtx.DB.Create(&msg).Error; err != nil {
		return &super.RecordLlmChatTurnResp{Ok: false}, nil
	}
	return &super.RecordLlmChatTurnResp{Ok: true}, nil
}
