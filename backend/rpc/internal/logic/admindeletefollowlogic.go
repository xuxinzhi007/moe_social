package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteFollowLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteFollowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteFollowLogic {
	return &AdminDeleteFollowLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteFollowLogic) AdminDeleteFollow(in *super.AdminDeleteFollowReq) (*super.AdminDeleteFollowResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteFollow(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
