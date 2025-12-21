package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserCountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserCountLogic {
	return &GetUserCountLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *GetUserCountLogic) GetUserCount(in *rpc.GetUserCountReq) (*rpc.GetUserCountResp, error) {
	var total int64
	l.svcCtx.DB.Model(&model.User{}).Count(&total)

	return &rpc.GetUserCountResp{
		Count: int32(total),
	}, nil
}
