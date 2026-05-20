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

type UpsertUserMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserMemoryLogic {
	return &UpsertUserMemoryLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertUserMemoryLogic) UpsertUserMemory(in *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error) {
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}
	if in.Key == "" {
		return nil, errorx.InvalidArgument("key不能为空")
	}
	if strings.TrimSpace(in.Value) == "" {
		return nil, errorx.InvalidArgument("value不能为空")
	}
	if model.IsTechnicalUserMemory(in.Key, in.Source) {
		return nil, errorx.InvalidArgument("设备信息请使用设备同步接口 /devices/sync，不可写入用户记忆")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	memoryType := normalizeMemoryType(in.MemoryType)
	if memoryType == "" {
		memoryType = inferMemoryTypeByKey(in.Key)
	}
	confidence := clampConfidence(in.Confidence)
	source := normalizeSource(in.Source)
	sourceMsgID := in.SourceMsgId
	sessionID := in.SessionId

	var memory model.UserMemory
	db := l.svcCtx.DB.Where("user_id = ? AND `key` = ?", uint(userID), in.Key).First(&memory)
	if db.Error != nil {
		if db.Error == gorm.ErrRecordNotFound {
			// 软删除记录仍占用 (user_id, key) 唯一索引，需恢复而非 INSERT。
			var deleted model.UserMemory
			if err := l.svcCtx.DB.Unscoped().
				Where("user_id = ? AND `key` = ?", uint(userID), in.Key).
				First(&deleted).Error; err == nil {
				memory = deleted
				memory.DeletedAt = gorm.DeletedAt{}
				memory.Value = in.Value
				memory.MemoryType = memoryType
				memory.Confidence = confidence
				memory.Source = source
				if sourceMsgID != "" {
					memory.SourceMsgID = sourceMsgID
				}
				if sessionID != "" {
					memory.SessionID = sessionID
				}
				if err := l.svcCtx.DB.Unscoped().Save(&memory).Error; err != nil {
					l.Errorf("恢复用户记忆失败: %v", err)
					return nil, errorx.Internal("创建用户记忆失败")
				}
			} else if err == gorm.ErrRecordNotFound {
				memory = model.UserMemory{
					UserID:      uint(userID),
					Key:         in.Key,
					Value:       in.Value,
					MemoryType:  memoryType,
					Confidence:  confidence,
					Source:      source,
					SourceMsgID: sourceMsgID,
					SessionID:   sessionID,
				}
				if err := l.svcCtx.DB.Omit("User").Create(&memory).Error; err != nil {
					l.Errorf("创建用户记忆失败: %v", err)
					return nil, errorx.Internal("创建用户记忆失败")
				}
			} else {
				l.Errorf("查询用户记忆失败: %v", err)
				return nil, errorx.Internal("查询用户记忆失败")
			}
		} else {
			l.Errorf("查询用户记忆失败: %v", db.Error)
			return nil, errorx.Internal("查询用户记忆失败")
		}
	} else {
		// 冲突处理：已有人工修订记忆优先，避免被低置信自动抽取覆盖。
		if isManualSource(memory.Source) && !isManualSource(source) && in.Value != memory.Value && confidence <= memory.Confidence {
			return &super.UpsertUserMemoryResp{
				Memory: &super.UserMemory{
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
				},
			}, nil
		}

		memory.Value = in.Value
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
		if err := l.svcCtx.DB.Save(&memory).Error; err != nil {
			l.Error("更新用户记忆失败: ", err)
			return nil, errorx.Internal("更新用户记忆失败")
		}
	}

	triggerUserMemoryProfileRebuildAsync(l.svcCtx.DB, uint(userID), l.Logger)
	indexMemoryEmbeddingAsync(l.svcCtx.DB, uint(userID), memory.Key, memory.Value, memory.Source, l.Logger)

	return &super.UpsertUserMemoryResp{
		Memory: &super.UserMemory{
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
		},
	}, nil
}
