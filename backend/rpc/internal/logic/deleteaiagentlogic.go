package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiAgentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiAgentLogic {
	return &DeleteAiAgentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *DeleteAiAgentLogic) DeleteAiAgent(in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).DeleteAiAgent(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("delete ai agent: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
