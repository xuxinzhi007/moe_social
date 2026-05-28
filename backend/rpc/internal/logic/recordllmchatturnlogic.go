package logic

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type RecordLlmChatTurnLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRecordLlmChatTurnLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RecordLlmChatTurnLogic {
	return &RecordLlmChatTurnLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RecordLlmChatTurnLogic) RecordLlmChatTurn(in *moe.RecordLlmChatTurnReq) (*moe.RecordLlmChatTurnResp, error) {
	return llmbiz.RecordChatTurn(l.ctx, l.svcCtx.DB, in)
}
