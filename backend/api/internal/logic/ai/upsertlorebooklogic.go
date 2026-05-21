// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package ai

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertLorebookLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpsertLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertLorebookLogic {
	return &UpsertLorebookLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpsertLorebookLogic) UpsertLorebook(req *types.AiLorebookUpsertReq) (resp *types.BaseResp, err error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	full, err := NewResourceLogic(l.ctx, l.svcCtx).UpsertLorebook(userID, req.Data, req.Entries)
	if err != nil {
		return nil, err
	}
	return &full.BaseResp, nil
}
