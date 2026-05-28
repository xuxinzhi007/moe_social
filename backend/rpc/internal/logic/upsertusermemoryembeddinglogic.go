package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertUserMemoryEmbeddingLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertUserMemoryEmbeddingLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserMemoryEmbeddingLogic {
	return &UpsertUserMemoryEmbeddingLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertUserMemoryEmbeddingLogic) UpsertUserMemoryEmbedding(in *super.UpsertUserMemoryEmbeddingReq) (*super.UpsertUserMemoryEmbeddingResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).UpsertUserMemoryEmbedding(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
