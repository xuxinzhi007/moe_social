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
	return &DeleteAiAgentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteAiAgentLogic) DeleteAiAgent(in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	// todo: add your logic here and delete this line

	return &super.DeleteAiResourceResp{}, nil
}
