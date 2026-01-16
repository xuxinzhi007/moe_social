package logic

import (
	"context"
	"strconv"

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

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	var memory model.UserMemory
	db := l.svcCtx.DB.Where("user_id = ? AND `key` = ?", uint(userID), in.Key).First(&memory)
	if db.Error != nil {
		if db.Error == gorm.ErrRecordNotFound {
			memory = model.UserMemory{
				UserID: uint(userID),
				Key:    in.Key,
				Value:  in.Value,
			}
			if err := l.svcCtx.DB.Create(&memory).Error; err != nil {
				l.Error("创建用户记忆失败: ", err)
				return nil, errorx.Internal("创建用户记忆失败")
			}
		} else {
			l.Error("查询用户记忆失败: ", db.Error)
			return nil, errorx.Internal("查询用户记忆失败")
		}
	} else {
		memory.Value = in.Value
		if err := l.svcCtx.DB.Save(&memory).Error; err != nil {
			l.Error("更新用户记忆失败: ", err)
			return nil, errorx.Internal("更新用户记忆失败")
		}
	}

	return &super.UpsertUserMemoryResp{
		Memory: &super.UserMemory{
			Id:        strconv.Itoa(int(memory.ID)),
			UserId:    strconv.Itoa(int(memory.UserID)),
			Key:       memory.Key,
			Value:     memory.Value,
			CreatedAt: memory.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt: memory.UpdatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}

