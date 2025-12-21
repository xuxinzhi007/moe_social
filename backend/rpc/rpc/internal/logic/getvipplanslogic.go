package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipPlansLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipPlansLogic {
	return &GetVipPlansLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// VIP套餐相关服务
func (l *GetVipPlansLogic) GetVipPlans(in *rpc.GetVipPlansReq) (*rpc.GetVipPlansResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetVipPlansResp{}, nil
}
