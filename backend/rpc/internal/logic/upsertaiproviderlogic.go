package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiProviderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiProviderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiProviderLogic {
	return &UpsertAiProviderLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpsertAiProviderLogic) UpsertAiProvider(in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).UpsertAiProvider(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("upsert ai provider: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
