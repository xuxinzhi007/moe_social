package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGroupsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGroupsLogic {
	return &AdminListGroupsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListGroupsLogic) AdminListGroups(in *super.AdminListGroupsReq) (*super.AdminListGroupsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListGroups(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
