// Code scaffolded by goctl. Safe to edit.

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapVipPlansLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapVipPlansLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapVipPlansLogic {
	return &AdminBootstrapVipPlansLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapVipPlansLogic) AdminBootstrapVipPlans(_ *types.EmptyReq) (resp *types.AdminBootstrapVipPlansResp, err error) {
	created, err := l.svcCtx.VipGW.BootstrapPlans(l.ctx)
	if err != nil {
		return &types.AdminBootstrapVipPlansResp{
			BaseResp: common.HandleVipGWError(err, ""),
		}, nil
	}

	msg := "ok"
	if created > 0 {
		msg = "已导入默认套餐"
	} else {
		msg = "已有套餐，未导入"
	}

	resp = &types.AdminBootstrapVipPlansResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data: types.AdminBootstrapVipPlansData{
			Created: created,
		},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "vip_plan", "", "导入默认 VIP 套餐")
	}
	return resp, nil
}
