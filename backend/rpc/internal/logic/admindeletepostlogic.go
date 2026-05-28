package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeletePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeletePostLogic {
	return &AdminDeletePostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeletePostLogic) AdminDeletePost(in *moe.AdminDeletePostReq) (*moe.AdminDeletePostResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeletePost(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
