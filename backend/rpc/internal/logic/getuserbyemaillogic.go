package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserByEmailLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserByEmailLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserByEmailLogic {
	return &GetUserByEmailLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserByEmailLogic) GetUserByEmail(in *super.GetUserByEmailReq) (*super.GetUserByEmailResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).GetUserByEmail(l.ctx, in)
	return resp, mapUserBizErr(err)
}
