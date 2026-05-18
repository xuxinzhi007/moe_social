package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListAiProvidersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListAiProvidersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListAiProvidersLogic {
	return &ListAiProvidersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListAiProvidersLogic) ListAiProviders(in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).list("providers", in)
}
