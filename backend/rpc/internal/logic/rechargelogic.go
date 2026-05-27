package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type RechargeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRechargeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RechargeLogic {
	return &RechargeLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *RechargeLogic) Recharge(in *super.RechargeReq) (*super.RechargeResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).Recharge(l.ctx, in)
	return resp, mapUserBizErr(err)
}
