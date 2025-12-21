package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

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

func (l *CheckUserVipLogic) CheckUserVip(in *rpc.CheckUserVipReq) (*rpc.CheckUserVipResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.CheckUserVipResp{}, nil
}
