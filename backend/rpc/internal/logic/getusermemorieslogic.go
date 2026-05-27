package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoriesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoriesLogic {
	return &GetUserMemoriesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserMemoriesLogic) GetUserMemories(in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).GetUserMemories(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
