package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAchievementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAchievementsLogic {
	return &AdminListAchievementsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAchievementsLogic) AdminListAchievements(req *types.AdminListAchievementsReq) (*types.AdminListAchievementsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAchievements(l.ctx, &super.AdminListAchievementsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
		Category: req.Category,
	})
	if err != nil {
		return &types.AdminListAchievementsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAchievementItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminAchievementToTypes(item)
	}
	return &types.AdminListAchievementsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListAchievementsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
