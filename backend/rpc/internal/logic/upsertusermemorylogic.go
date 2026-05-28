package logic

import (
	"context"

	"backend/internal/adapter/moeconfig"
	llmbiz "backend/internal/biz/llm"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertUserMemoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserMemoryLogic {
	return &UpsertUserMemoryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpsertUserMemoryLogic) UpsertUserMemory(in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	resp, err := llmbiz.UpsertUserMemory(l.ctx, l.svcCtx.DB, in, llmbiz.MemoryWriteOptions{
		InferenceBaseURL: moeconfig.InferenceFromViper().BaseURL,
	})
	if err != nil {
		if mapped := mapMemoryWriteErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("upsert user memory: %v", err)
		return nil, mapMemoryWriteErr(err)
	}
	return resp, nil
}
