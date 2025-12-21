package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserVipStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserVipStatusLogic {
	return &GetUserVipStatusLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *GetUserVipStatusLogic) GetUserVipStatus(in *rpc.GetUserVipStatusReq) (*rpc.GetUserVipStatusResp, error) {
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	return &rpc.GetUserVipStatusResp{
		IsVip:     user.IsVip,
		ExpiresAt: vipEndAt,
		AutoRenew: false, // 模型中暂时没有auto_renew字段
	}, nil
}
