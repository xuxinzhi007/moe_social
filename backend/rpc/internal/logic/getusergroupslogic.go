package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserGroupsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserGroupsLogic {
	return &GetUserGroupsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserGroupsLogic) GetUserGroups(in *super.GetUserGroupsReq) (*super.GetUserGroupsResp, error) {
	return communityapp.New(l.svcCtx.DB).GetUserGroups(l.ctx, in)
}
