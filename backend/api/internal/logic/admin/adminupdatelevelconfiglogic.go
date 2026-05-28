package admin

import (
	"context"
	"fmt"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateLevelConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateLevelConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateLevelConfigLogic {
	return &AdminUpdateLevelConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateLevelConfigLogic) AdminUpdateLevelConfig(req *types.AdminUpdateLevelConfigReq) (*types.AdminUpdateLevelConfigResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateLevelConfig(l.ctx, &moe.AdminUpdateLevelConfigReq{
		Id:               req.LevelId,
		Title:            req.Title,
		MinExp:           int32(req.MinExp),
		MaxExp:           int32(req.MaxExp),
		Privileges:       req.Privileges,
		BadgeUrl:         req.BadgeUrl,
		UpdateTitle:      req.UpdateTitle,
		UpdateMinExp:     req.UpdateMinExp,
		UpdateMaxExp:     req.UpdateMaxExp,
		UpdatePrivileges: req.UpdatePrivileges,
		UpdateBadgeUrl:   req.UpdateBadgeUrl,
	})
	if err != nil {
		return &types.AdminUpdateLevelConfigResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	resp := &types.AdminUpdateLevelConfigResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminLevelConfigToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "level_config", fmt.Sprintf("%d", req.LevelId), "更新等级配置")
	}
	return resp, nil
}
