package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetUserProfileLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetUserProfileLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserProfileLogic {
	return &AdminGetUserProfileLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetUserProfileLogic) AdminGetUserProfile(in *moe.AdminGetUserProfileReq) (*moe.AdminGetUserProfileResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).GetUserProfile(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
