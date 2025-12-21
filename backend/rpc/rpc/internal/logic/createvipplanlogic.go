package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipPlanLogic {
	return &CreateVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateVipPlanLogic) CreateVipPlan(in *rpc.CreateVipPlanReq) (*rpc.CreateVipPlanResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.CreateVipPlanResp{}, nil
}
