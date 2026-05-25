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
)

type AdminDeleteAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAccountLogic {
	return &AdminDeleteAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteAccountLogic) AdminDeleteAccount(in *super.AdminDeleteAccountReq) (*super.AdminDeleteAccountResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAccountId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("账号 ID 无效")
	}
	if err := l.svcCtx.DB.First(&model.AdminAccount{}, id).Error; err != nil {
		return nil, errorx.NotFound("管理员不存在")
	}
	var count int64
	if err := l.svcCtx.DB.Model(&model.AdminAccount{}).Count(&count).Error; err != nil {
		return nil, errorx.Internal("删除管理员失败")
	}
	if count <= 1 {
		return nil, errorx.InvalidArgument("至少保留一名管理员")
	}
	if err := l.svcCtx.DB.Delete(&model.AdminAccount{}, id).Error; err != nil {
		l.Errorf("[admin] delete account: %v", err)
		return nil, errorx.Internal("删除管理员失败")
	}
	return &super.AdminDeleteAccountResp{}, nil
}
