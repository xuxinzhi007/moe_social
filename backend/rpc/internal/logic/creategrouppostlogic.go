package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateGroupPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateGroupPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateGroupPostLogic {
	return &CreateGroupPostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *CreateGroupPostLogic) CreateGroupPost(in *moe.CreateGroupPostReq) (*moe.CreateGroupPostResp, error) {
	return communityapp.New(l.svcCtx.DB).CreateGroupPost(l.ctx, in)
}
