// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package ai

import (
	"context"
	"errors"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteLorebookLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteLorebookLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteLorebookLogic {
	return &DeleteLorebookLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteLorebookLogic) DeleteLorebook(req *types.AiResourceDeleteReq) (resp *types.BaseResp, err error) {
	if req.Id == "" {
		return nil, errors.New("missing lorebook id")
	}
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	full, err := NewResourceLogic(l.ctx, l.svcCtx).DeleteLorebook(userID, req.Id)
	if err != nil {
		return nil, err
	}
	return &full.BaseResp, nil
}
