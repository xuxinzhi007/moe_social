package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SubmitUserMemoryFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSubmitUserMemoryFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitUserMemoryFeedbackLogic {
	return &SubmitUserMemoryFeedbackLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *SubmitUserMemoryFeedbackLogic) SubmitUserMemoryFeedback(in *moe.SubmitUserMemoryFeedbackReq) (*moe.SubmitUserMemoryFeedbackResp, error) {
	resp, err := newLLMApp(l.svcCtx.DB).SubmitUserMemoryFeedback(l.ctx, in)
	return resp, mapMemoryWriteErr(err)
}
