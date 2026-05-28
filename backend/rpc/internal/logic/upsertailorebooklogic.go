package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiLorebookLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiLorebookLogic {
	return &UpsertAiLorebookLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpsertAiLorebookLogic) UpsertAiLorebook(in *moe.UpsertAiResourceReq) (*moe.UpsertAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).UpsertAiLorebook(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("upsert ai lorebook: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
