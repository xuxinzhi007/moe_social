package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserMemoryEmbeddingsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserMemoryEmbeddingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserMemoryEmbeddingsLogic {
	return &ListUserMemoryEmbeddingsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListUserMemoryEmbeddingsLogic) ListUserMemoryEmbeddings(in *moe.ListUserMemoryEmbeddingsReq) (*moe.ListUserMemoryEmbeddingsResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).ListUserMemoryEmbeddings(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
