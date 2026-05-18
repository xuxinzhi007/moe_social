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
	return &UpsertAiProviderLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertAiProviderLogic) UpsertAiProvider(in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).upsert("providers", in)
}
