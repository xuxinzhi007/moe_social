package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMemoryLogic {
	return &AdminDeleteMemoryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteMemoryLogic) AdminDeleteMemory(in *moe.AdminDeleteMemoryReq) (*moe.AdminDeleteMemoryResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).DeleteMemory(l.ctx, in)
	if err != nil {
		return nil, mapAdminModerationErr(err)
	}
	return resp, nil
}
