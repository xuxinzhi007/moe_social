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
	return &ListPublicAiAgentsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListPublicAiAgentsLogic) ListPublicAiAgents(in *super.ListPublicAiAgentsReq) (*super.ListAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).ListPublicAiAgents(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("list public ai agents: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
