package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapLevelsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapLevelsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapLevelsLogic {
	return &AdminBootstrapLevelsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminBootstrapLevelsLogic) AdminBootstrapLevels(_ *types.EmptyReq) (*types.AdminBootstrapLevelsResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminBootstrapLevels(l.ctx, &super.AdminBootstrapLevelsReq{})
	if err != nil {
		return &types.AdminBootstrapLevelsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminBootstrapLevelsResp{
		BaseResp: common.HandleRPCError(nil, "初始化成功"),
		Data: types.AdminBootstrapLevelsData{
			LevelConfigsCreated:   int(rpcResp.GetLevelConfigsCreated()),
			CheckInRewardsCreated: int(rpcResp.GetCheckInRewardsCreated()),
		},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "level_config", "", "导入默认等级配置")
	}
	return resp, nil
}
