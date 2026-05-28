package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateAutoRenewLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateAutoRenewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateAutoRenewLogic {
	return &UpdateAutoRenewLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpdateAutoRenewLogic) UpdateAutoRenew(in *moe.UpdateAutoRenewReq) (*moe.UpdateAutoRenewResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).UpdateAutoRenew(l.ctx, in)
	return resp, mapUserBizErr(err)
}
