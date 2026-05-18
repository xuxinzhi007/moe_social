package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiLorebookLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiLorebookLogic {
	return &DeleteAiLorebookLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteAiLorebookLogic) DeleteAiLorebook(in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).delete("lorebooks", in)
}
