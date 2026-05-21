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

type DeleteProviderLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteProviderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteProviderLogic {
	return &DeleteProviderLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteProviderLogic) DeleteProvider(req *types.AiResourceDeleteReq) (resp *types.BaseResp, err error) {
	if req.Id == "" {
		return nil, errors.New("missing provider id")
	}
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	full, err := NewResourceLogic(l.ctx, l.svcCtx).DeleteProvider(userID, req.Id)
	if err != nil {
		return nil, err
	}
	return &full.BaseResp, nil
}
