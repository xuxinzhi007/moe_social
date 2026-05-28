package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserMemoryRelationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserMemoryRelationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserMemoryRelationsLogic {
	return &ListUserMemoryRelationsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListUserMemoryRelationsLogic) ListUserMemoryRelations(in *moe.ListUserMemoryRelationsReq) (*moe.ListUserMemoryRelationsResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).ListUserMemoryRelations(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
