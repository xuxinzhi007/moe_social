package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertAiLorebookLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertAiLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertAiLorebookLogic {
	return &UpsertAiLorebookLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertAiLorebookLogic) UpsertAiLorebook(in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	// todo: add your logic here and delete this line

	return &super.UpsertAiResourceResp{}, nil
}
