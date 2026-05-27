package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserCountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserCountLogic {
	return &GetUserCountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserCountLogic) GetUserCount(in *super.GetUserCountReq) (*super.GetUserCountResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).GetUserCount(l.ctx, in)
	return resp, mapUserBizErr(err)
}
