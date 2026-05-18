package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListAiAgentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListAiAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListAiAgentsLogic {
	return &ListAiAgentsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListAiAgentsLogic) ListAiAgents(in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	// todo: add your logic here and delete this line

	return &super.ListAiResourceResp{}, nil
}
