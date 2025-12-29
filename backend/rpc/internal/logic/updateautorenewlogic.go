package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateAutoRenewLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateAutoRenewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateAutoRenewLogic {
	return &UpdateAutoRenewLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}
// 用户相关服务
func (l *UpdateAutoRenewLogic) UpdateAutoRenew(in *super.UpdateAutoRenewReq) (*super.UpdateAutoRenewResp, error) {
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 目前模型中没有auto_renew字段，这里先返回成功
	return &super.UpdateAutoRenewResp{}, nil
}
