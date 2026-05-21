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

type DeleteAgentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteAgentLogic {
	return &DeleteAgentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteAgentLogic) DeleteAgent(req *types.AiResourceDeleteReq) (resp *types.BaseResp, err error) {
	if req.Id == "" {
		return nil, errors.New("missing agent id")
	}
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	full, err := NewResourceLogic(l.ctx, l.svcCtx).DeleteAgent(userID, req.Id)
	if err != nil {
		return nil, err
	}
	return &full.BaseResp, nil
}
