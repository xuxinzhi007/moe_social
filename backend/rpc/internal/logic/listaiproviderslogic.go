package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListAiProvidersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListAiProvidersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListAiProvidersLogic {
	return &ListAiProvidersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListAiProvidersLogic) ListAiProviders(in *moe.ListAiResourceReq) (*moe.ListAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).ListAiProviders(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("list ai providers: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
