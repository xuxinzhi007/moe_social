package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiAgentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiAgentLogic {
	return &UpsertAiAgentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *UpsertAiAgentLogic) UpsertAiAgent(in *moe.UpsertAiResourceReq) (*moe.UpsertAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).UpsertAiAgent(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("upsert ai agent: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
