package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPublicAiAgentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListPublicAiAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPublicAiAgentsLogic {
	return &ListPublicAiAgentsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListPublicAiAgentsLogic) ListPublicAiAgents(in *super.ListPublicAiAgentsReq) (*super.ListAiResourceResp, error) {
	return NewAiResourcesLogic(l.ctx, l.svcCtx).listPublicAgents(in)
}
