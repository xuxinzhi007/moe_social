package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckUserVipLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckUserVipLogic {
	return &CheckUserVipLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}
// 用户相关服务
func (l *CheckUserVipLogic) CheckUserVip(in *super.CheckUserVipReq) (*super.CheckUserVipResp, error) {
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	return &super.CheckUserVipResp{
		IsVip: user.IsVip,
	}, nil
}
