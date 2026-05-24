// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListVipPlans(l.ctx, &super.AdminListVipPlansReq{
		Page:           int32(page),
		PageSize:       int32(pageSize),
		Keyword:        req.Keyword,
		IncludeDeleted: req.IncludeDeleted,
	})
	if err != nil {
		return &types.AdminListVipPlansResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	items := make([]types.VipPlan, 0, len(rpcResp.GetPlans()))
	for _, p := range rpcResp.GetPlans() {
		items = append(items, common.RpcVipPlanToTypes(p))
	}

	return &types.AdminListVipPlansResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListVipPlansData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
