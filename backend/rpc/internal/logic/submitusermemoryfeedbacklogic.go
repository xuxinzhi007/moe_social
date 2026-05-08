package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type SubmitUserMemoryFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSubmitUserMemoryFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitUserMemoryFeedbackLogic {
	return &SubmitUserMemoryFeedbackLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SubmitUserMemoryFeedbackLogic) SubmitUserMemoryFeedback(in *super.SubmitUserMemoryFeedbackReq) (*super.SubmitUserMemoryFeedbackResp, error) {
	if strings.TrimSpace(in.UserId) == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}
	if strings.TrimSpace(in.Key) == "" {
		return nil, errorx.InvalidArgument("key不能为空")
	}
	feedbackType := strings.ToLower(strings.TrimSpace(in.FeedbackType))
	if feedbackType != "accept" && feedbackType != "reject" && feedbackType != "correct" {
		return nil, errorx.InvalidArgument("feedback_type必须是accept/reject/correct")
	}
	if feedbackType == "correct" && strings.TrimSpace(in.CorrectedValue) == "" {
		return nil, errorx.InvalidArgument("correct反馈必须提供corrected_value")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	var memory model.UserMemory
	if err := l.svcCtx.DB.Where("user_id = ? AND `key` = ?", uint(userID), in.Key).First(&memory).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.NotFound("用户记忆不存在")
		}
		l.Errorf("query user memory failed: %v", err)
		return nil, errorx.Internal("查询用户记忆失败")
	}

	oldValue := memory.Value
	reason := strings.TrimSpace(in.Reason)

	switch feedbackType {
	case "accept":
		memory.Confidence = minFloat(memory.Confidence+0.08, 1)
		memory.Source = "feedback_accept"
	case "reject":
		memory.Confidence = maxFloat(memory.Confidence-0.2, 0.05)
		memory.Source = "feedback_reject"
	case "correct":
		memory.Value = strings.TrimSpace(in.CorrectedValue)
		memory.Confidence = maxFloat(memory.Confidence, 0.9)
		memory.Source = "manual_correct"
	}

	if err := l.svcCtx.DB.Transaction(func(tx *gorm.DB) error {
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
		l.Errorf("submit user memory feedback failed: %v", err)
		return nil, errorx.Internal("提交用户记忆反馈失败")
	}

	return &super.SubmitUserMemoryFeedbackResp{
		Memory: &super.UserMemory{
			Id:         strconv.Itoa(int(memory.ID)),
			UserId:     strconv.Itoa(int(memory.UserID)),
			Key:        memory.Key,
			Value:      memory.Value,
			MemoryType: memory.MemoryType,
			Confidence: memory.Confidence,
			Source:     memory.Source,
			CreatedAt:  memory.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:  memory.UpdatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
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
