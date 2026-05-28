package llmbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/internal/adapter/moeconfig"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

var (
	ErrMemoryEmptyUserID = errors.New("user_id不能为空")
	ErrMemoryEmptyKey    = errors.New("key不能为空")
	ErrMemoryEmptyValue  = errors.New("value不能为空")
	ErrMemoryInvalidUser = errors.New("无效的user_id")
	ErrMemoryTechnical   = errors.New("设备信息请使用设备同步接口 /devices/sync，不可写入用户记忆")
)

// MemoryWriteOptions 记忆写入后异步任务配置。
type MemoryWriteOptions struct {
	InferenceBaseURL string
}

// UpsertUserMemory 创建或更新用户记忆（含冲突策略与异步索引）。
func UpsertUserMemory(ctx context.Context, st MemoryStore, in *moe.UpsertUserMemoryReq, opts MemoryWriteOptions) (*moe.UpsertUserMemoryResp, error) {
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	if in.GetUserId() == "" {
		return nil, ErrMemoryEmptyUserID
	}
	if in.GetKey() == "" {
		return nil, ErrMemoryEmptyKey
	}
	if strings.TrimSpace(in.GetValue()) == "" {
		return nil, ErrMemoryEmptyValue
	}
	if model.IsTechnicalUserMemory(in.GetKey(), in.GetSource()) {
		return nil, ErrMemoryTechnical
	}

	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrMemoryInvalidUser
	}

	memoryType := normalizeMemoryType(in.GetMemoryType())
	if memoryType == "" {
		memoryType = inferMemoryTypeByKey(in.GetKey())
	}
	confidence := clampConfidence(in.GetConfidence())
	source := normalizeSource(in.GetSource())
	sourceMsgID := in.GetSourceMsgId()
	sessionID := in.GetSessionId()

	var memory model.UserMemory
	dbResult := db.WithContext(ctx).Where("user_id = ? AND `key` = ?", uint(userID), in.GetKey()).First(&memory)
	if dbResult.Error != nil {
		if errors.Is(dbResult.Error, gorm.ErrRecordNotFound) {
			var deleted model.UserMemory
			if err := db.WithContext(ctx).Unscoped().
				Where("user_id = ? AND `key` = ?", uint(userID), in.GetKey()).
				First(&deleted).Error; err == nil {
				memory = deleted
				memory.DeletedAt = gorm.DeletedAt{}
				memory.Value = in.GetValue()
				memory.MemoryType = memoryType
				memory.Confidence = confidence
				memory.Source = source
				if sourceMsgID != "" {
					memory.SourceMsgID = sourceMsgID
				}
				if sessionID != "" {
					memory.SessionID = sessionID
				}
				if err := db.WithContext(ctx).Unscoped().Save(&memory).Error; err != nil {
					return nil, err
				}
			} else if errors.Is(err, gorm.ErrRecordNotFound) {
				memory = model.UserMemory{
					UserID:      uint(userID),
					Key:         in.GetKey(),
					Value:       in.GetValue(),
					MemoryType:  memoryType,
					Confidence:  confidence,
					Source:      source,
					SourceMsgID: sourceMsgID,
					SessionID:   sessionID,
				}
				if err := db.WithContext(ctx).Omit("User").Create(&memory).Error; err != nil {
					return nil, err
				}
			} else {
				return nil, err
			}
		} else {
			return nil, dbResult.Error
		}
	} else {
		if isManualSource(memory.Source) && !isManualSource(source) && in.GetValue() != memory.Value && confidence <= memory.Confidence {
			return &moe.UpsertUserMemoryResp{Memory: userMemoryToProto(memory)}, nil
		}
		memory.Value = in.GetValue()
		memory.MemoryType = memoryType
		if isManualSource(source) && confidence < memory.Confidence {
			confidence = memory.Confidence
		}
		memory.Confidence = confidence
		memory.Source = source
		if sourceMsgID != "" {
			memory.SourceMsgID = sourceMsgID
		}
		if sessionID != "" {
			memory.SessionID = sessionID
		}
		if err := db.WithContext(ctx).Save(&memory).Error; err != nil {
			return nil, err
		}
	}

	baseURL := strings.TrimSpace(opts.InferenceBaseURL)
	if baseURL == "" {
		baseURL = moeconfig.InferenceFromViper().BaseURL
	}
	triggerAfterMemoryWrite(db, uint(userID), memory, baseURL)

	return &moe.UpsertUserMemoryResp{Memory: userMemoryToProto(memory)}, nil
}

func userMemoryToProto(memory model.UserMemory) *moe.UserMemory {
	return &moe.UserMemory{
		Id:          strconv.Itoa(int(memory.ID)),
		UserId:      strconv.Itoa(int(memory.UserID)),
		Key:         memory.Key,
		Value:       memory.Value,
		MemoryType:  memory.MemoryType,
		Confidence:  memory.Confidence,
		Source:      memory.Source,
		SourceMsgId: memory.SourceMsgID,
		SessionId:   memory.SessionID,
		CreatedAt:   memory.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:   memory.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}
