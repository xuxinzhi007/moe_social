package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiAgentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiAgentLogic {
	return &UpsertAiAgentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertAiAgentLogic) UpsertAiAgent(in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	// todo: add your logic here and delete this line

	return &super.UpsertAiResourceResp{}, nil
}
