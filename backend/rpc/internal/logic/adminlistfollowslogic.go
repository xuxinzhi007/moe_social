package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListFollowsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListFollowsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFollowsLogic {
	return &AdminListFollowsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListFollowsLogic) AdminListFollows(in *super.AdminListFollowsReq) (*super.AdminListFollowsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListFollows(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
