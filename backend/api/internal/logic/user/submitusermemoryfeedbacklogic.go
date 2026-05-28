// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SubmitUserMemoryFeedbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSubmitUserMemoryFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitUserMemoryFeedbackLogic {
	return &SubmitUserMemoryFeedbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SubmitUserMemoryFeedbackLogic) SubmitUserMemoryFeedback(req *types.SubmitUserMemoryFeedbackReq) (resp *types.SubmitUserMemoryFeedbackResp, err error) {
	rpcResp, err := l.svcCtx.LLMGW.SubmitUserMemoryFeedback(l.ctx, &moe.SubmitUserMemoryFeedbackReq{
		UserId:         req.UserId,
		Key:            req.Key,
		FeedbackType:   req.FeedbackType,
		CorrectedValue: req.CorrectedValue,
		Reason:         req.Reason,
	})
	if err != nil {
		return &types.SubmitUserMemoryFeedbackResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	m := rpcResp.Memory
	return &types.SubmitUserMemoryFeedbackResp{
		BaseResp: common.HandleRPCError(nil, "提交记忆反馈成功"),
		Data: types.UserMemory{
			Id:          m.Id,
			UserId:      m.UserId,
			Key:         m.Key,
			Value:       m.Value,
			MemoryType:  m.MemoryType,
			Confidence:  m.Confidence,
			Source:      m.Source,
			SourceMsgId: m.SourceMsgId,
			SessionId:   m.SessionId,
			CreatedAt:   m.CreatedAt,
			UpdatedAt:   m.UpdatedAt,
		},
	}, nil
}
