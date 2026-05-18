package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteAiLorebookLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteAiLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAiLorebookLogic {
	return &DeleteAiLorebookLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteAiLorebookLogic) DeleteAiLorebook(in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	// todo: add your logic here and delete this line

	return &super.DeleteAiResourceResp{}, nil
}
