package logic

import (
	"context"

	communityapp "backend/internal/service/community"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupPostsLogic {
	return &GetGroupPostsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetGroupPostsLogic) GetGroupPosts(in *moe.GetGroupPostsReq) (*moe.GetGroupPostsResp, error) {
	return communityapp.New(l.svcCtx.DB).GetGroupPosts(l.ctx, in)
}
