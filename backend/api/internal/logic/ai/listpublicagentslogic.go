// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package ai

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPublicAgentsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListPublicAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPublicAgentsLogic {
	return &ListPublicAgentsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListPublicAgentsLogic) ListPublicAgents(req *types.ListPublicAiAgentsReq) (resp *types.AiAgentsResp, err error) {
	limit := int32(req.Limit)
	if limit <= 0 {
		limit = 50
	}
	return NewResourceLogic(l.ctx, l.svcCtx).ListPublicAgents(limit)
}
