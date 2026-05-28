package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCommentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCommentsLogic {
	return &AdminListCommentsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListCommentsLogic) AdminListComments(in *moe.AdminListCommentsReq) (*moe.AdminListCommentsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListComments(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
