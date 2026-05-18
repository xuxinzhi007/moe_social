package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiProviderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiProviderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiProviderLogic {
	return &DeleteAiProviderLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteAiProviderLogic) DeleteAiProvider(in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).delete("providers", in)
}
