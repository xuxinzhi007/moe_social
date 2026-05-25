package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAchievementLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateAchievementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAchievementLogic {
	return &AdminUpdateAchievementLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateAchievementLogic) AdminUpdateAchievement(req *types.AdminUpdateAchievementReq) (*types.AdminUpdateAchievementResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateAchievement(l.ctx, &super.AdminUpdateAchievementReq{
		Id:                req.AchievementId,
		Name:              req.Name,
		Description:       req.Description,
		Enabled:           req.Enabled,
		ExpReward:         int32(req.ExpReward),
		SortOrder:         int32(req.SortOrder),
		UpdateName:        req.UpdateName,
		UpdateDescription: req.UpdateDescription,
		UpdateEnabled:     req.UpdateEnabled,
		UpdateExpReward:   req.UpdateExpReward,
		UpdateSortOrder:   req.UpdateSortOrder,
	})
	if err != nil {
		return &types.AdminUpdateAchievementResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpdateAchievementResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminAchievementToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "achievement", req.AchievementId, "更新成就定义")
	}
	return resp, nil
}
