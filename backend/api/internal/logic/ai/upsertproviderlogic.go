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

type UpsertProviderLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpsertProviderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertProviderLogic {
	return &UpsertProviderLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpsertProviderLogic) UpsertProvider(req *types.AiResourceUpsertReq) (resp *types.BaseResp, err error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	full, err := NewResourceLogic(l.ctx, l.svcCtx).UpsertProvider(userID, req.Data)
	if err != nil {
		return nil, err
	}
	return &full.BaseResp, nil
}
