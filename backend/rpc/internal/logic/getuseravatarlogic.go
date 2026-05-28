package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAvatarLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAvatarLogic {
	return &GetUserAvatarLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserAvatarLogic) GetUserAvatar(in *moe.GetUserAvatarReq) (*moe.GetUserAvatarResp, error) {
	return userbiz.GetUserAvatar(l.ctx, l.svcCtx.DB, in)
}
