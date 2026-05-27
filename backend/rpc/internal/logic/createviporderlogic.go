package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipOrderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipOrderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipOrderLogic {
	return &CreateVipOrderLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *CreateVipOrderLogic) CreateVipOrder(in *super.CreateVipOrderReq) (*super.CreateVipOrderResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).CreateVipOrder(l.ctx, in)
	return resp, mapUserBizErr(err)
}
