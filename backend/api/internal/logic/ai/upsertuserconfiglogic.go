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

type UpsertUserConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpsertUserConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserConfigLogic {
	return &UpsertUserConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpsertUserConfigLogic) UpsertUserConfig(req *types.AiUserConfigReq) (resp *types.AiUserConfigResp, err error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	return NewUserConfigLogic(l.ctx, l.svcCtx).Upsert(userID, req)
}
