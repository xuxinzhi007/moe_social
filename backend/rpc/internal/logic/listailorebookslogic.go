package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListAiLorebooksLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListAiLorebooksLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListAiLorebooksLogic {
	return &ListAiLorebooksLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListAiLorebooksLogic) ListAiLorebooks(in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	resp, err := aiApp(l.svcCtx).ListAiLorebooks(l.ctx, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		l.Errorf("list ai lorebooks: %v", err)
		return nil, mapAIResourceErr(err)
	}
	return resp, nil
}
