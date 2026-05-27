package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupLogic {
	return &GetGroupLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGroupLogic) GetGroup(in *super.GetGroupReq) (*super.GetGroupResp, error) {
	return communityapp.New(l.svcCtx.DB).GetGroup(l.ctx, in)
}
