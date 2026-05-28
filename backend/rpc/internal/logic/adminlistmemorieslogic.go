package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMemoriesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMemoriesLogic {
	return &AdminListMemoriesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListMemoriesLogic) AdminListMemories(in *moe.AdminListMemoriesReq) (*moe.AdminListMemoriesResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListMemories(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
