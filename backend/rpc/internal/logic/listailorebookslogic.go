package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListAiLorebooksLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListAiLorebooksLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListAiLorebooksLogic {
	return &ListAiLorebooksLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListAiLorebooksLogic) ListAiLorebooks(in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).list("lorebooks", in)
}
