package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapMenusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapMenusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapMenusLogic {
	return &AdminBootstrapMenusLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminBootstrapMenusLogic) AdminBootstrapMenus(_ *types.EmptyReq) (*types.AdminBootstrapMenusResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminBootstrapMenus(l.ctx, &super.AdminBootstrapMenusReq{})
	if err != nil {
		return &types.AdminBootstrapMenusResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminBootstrapMenusResp{
		BaseResp: common.HandleRPCError(nil, "初始化成功"),
		Data:     types.AdminBootstrapMenusData{Created: int(rpcResp.GetCreated())},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "admin_menu", "", "导入默认侧栏菜单")
	}
	return resp, nil
}
