package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostsLogic {
	return &AdminListPostsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListPostsLogic) AdminListPosts(in *moe.AdminListPostsReq) (*moe.AdminListPostsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListPosts(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
