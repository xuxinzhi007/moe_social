package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteUserMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteUserMemoryLogic {
	return &DeleteUserMemoryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *DeleteUserMemoryLogic) DeleteUserMemory(in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).DeleteUserMemory(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
