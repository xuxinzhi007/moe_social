package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlanLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlanLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlanLogic {
	return &GetVipPlanLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipPlanLogic) GetVipPlan(in *rpc.GetVipPlanReq) (*rpc.GetVipPlanResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetVipPlanResp{}, nil
}
