package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiProviderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiProviderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiProviderLogic {
	return &DeleteAiProviderLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *DeleteAiProviderLogic) DeleteAiProvider(in *moe.DeleteAiResourceReq) (*moe.DeleteAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).DeleteAiProvider(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("delete ai provider: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
