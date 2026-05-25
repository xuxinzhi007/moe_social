package logic

import (
	"context"
	"errors"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminDeleteMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMemoryLogic {
	return &AdminDeleteMemoryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteMemoryLogic) AdminDeleteMemory(in *super.AdminDeleteMemoryReq) (*super.AdminDeleteMemoryResp, error) {
	id := in.GetMemoryId()
	if id == 0 {
		return nil, errorx.InvalidArgument("invalid memory_id")
	}
	result := l.svcCtx.DB.Delete(&model.UserMemory{}, id)
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("记忆不存在")
		}
		l.Errorf("[admin] delete memory: %v", result.Error)
		return nil, errorx.Internal("删除记忆失败")
	}
	if result.RowsAffected == 0 {
		return nil, errorx.NotFound("记忆不存在")
	}
	return &super.AdminDeleteMemoryResp{}, nil
}
