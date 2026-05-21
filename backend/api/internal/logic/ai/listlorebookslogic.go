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

type ListLorebooksLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListLorebooksLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLorebooksLogic {
	return &ListLorebooksLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListLorebooksLogic) ListLorebooks(req *types.EmptyReq) (resp *types.AiLorebooksResp, err error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	return NewResourceLogic(l.ctx, l.svcCtx).ListLorebooks(userID)
}
