package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiLorebookLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiLorebookLogic {
	return &DeleteAiLorebookLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *DeleteAiLorebookLogic) DeleteAiLorebook(in *moe.DeleteAiResourceReq) (*moe.DeleteAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).DeleteAiLorebook(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("delete ai lorebook: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
