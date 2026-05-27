// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipPlansLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipPlansLogic {
	return &AdminListVipPlansLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListVipPlansLogic) AdminListVipPlans(req *types.AdminListVipPlansReq) (resp *types.AdminListVipPlansResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rows, total, err := l.svcCtx.VipGW.ListPlans(l.ctx, vipbiz.ListPlansFilter{
		Page:           page,
		PageSize:       pageSize,
		Keyword:        req.Keyword,
		IncludeDeleted: req.IncludeDeleted,
	})
	if err != nil {
		return &types.AdminListVipPlansResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	items := make([]types.VipPlan, 0, len(rows))
	for _, p := range rows {
		items = append(items, common.VipPlanModelToTypes(p))
	}

	return &types.AdminListVipPlansResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListVipPlansData{
			Items: items,
			Total: int(total),
		},
	}, nil
}
