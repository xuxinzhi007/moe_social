package logic

import (
	"context"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserAvatarLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserAvatarLogic {
	return &UpdateUserAvatarLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserAvatarLogic) UpdateUserAvatar(in *moe.UpdateUserAvatarReq) (*moe.UpdateUserAvatarResp, error) {
	return userbiz.UpdateUserAvatar(l.ctx, l.svcCtx.DB, in)
}
