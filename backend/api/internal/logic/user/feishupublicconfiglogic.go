// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuPublicConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuPublicConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuPublicConfigLogic {
	return &FeishuPublicConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FeishuPublicConfigLogic) FeishuPublicConfig(req *types.EmptyReq) (resp *types.FeishuPublicConfigResp, err error) {
	cfg := utils.GetFeishuPublicConfig()
	return &types.FeishuPublicConfigResp{
		BaseResp: common.HandleRPCError(nil, ""),
		Data: types.FeishuPublicConfigData{
			Enabled:             cfg.Enabled,
			EnterpriseInviteURL: cfg.EnterpriseInviteURL,
			Notice:              cfg.Notice,
		},
	}, nil
}
