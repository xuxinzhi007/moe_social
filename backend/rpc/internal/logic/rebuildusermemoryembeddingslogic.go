package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type RebuildUserMemoryEmbeddingsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRebuildUserMemoryEmbeddingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RebuildUserMemoryEmbeddingsLogic {
	return &RebuildUserMemoryEmbeddingsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *RebuildUserMemoryEmbeddingsLogic) RebuildUserMemoryEmbeddings(in *moe.RebuildUserMemoryEmbeddingsReq) (*moe.RebuildUserMemoryEmbeddingsResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).RebuildUserMemoryEmbeddings(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
