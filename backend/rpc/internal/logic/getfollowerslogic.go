package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFollowersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetFollowersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFollowersLogic {
	return &GetFollowersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetFollowersLogic) GetFollowers(in *moe.GetFollowersReq) (*moe.GetFollowersResp, error) {
	app := userapp.New(l.svcCtx.DB)
	return app.GetFollowers(l.ctx, in)
}
