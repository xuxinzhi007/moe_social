package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMenuLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMenuLogic {
	return &AdminDeleteMenuLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteMenuLogic) AdminDeleteMenu(req *types.AdminDeleteMenuReq) (*types.AdminDeleteMenuResp, error) {
	_, err := l.svcCtx.SuperRpcClient.AdminDeleteMenu(l.ctx, &super.AdminDeleteMenuReq{
		MenuKey: req.MenuKey,
	})
	if err != nil {
		return &types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "admin_menu", req.MenuKey, "删除侧栏菜单")
	}
	return resp, nil
}
