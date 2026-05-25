package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapAchievementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapAchievementsLogic {
	return &AdminBootstrapAchievementsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapAchievementsLogic) AdminBootstrapAchievements(_ *types.EmptyReq) (resp *types.AdminBootstrapAchievementsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminBootstrapAchievements(l.ctx, &super.AdminBootstrapAchievementsReq{})
	if err != nil {
		return &types.AdminBootstrapAchievementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	msg := "成就表已有数据，未导入"
	if rpcResp.GetCreated() > 0 {
		msg = "已导入默认成就定义"
	}
	resp = &types.AdminBootstrapAchievementsResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     types.AdminBootstrapAchievementsData{Created: int(rpcResp.GetCreated())},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "achievement", "", "导入默认成就定义")
	}
	return resp, nil
}
