package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAccountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAccountLogic {
	return &AdminDeleteAccountLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteAccountLogic) AdminDeleteAccount(req *types.AdminDeleteAccountReq) (*types.AdminDeleteAccountResp, error) {
	_, err := l.svcCtx.AdminGW.AdminDeleteAccount(l.ctx, &moe.AdminDeleteAccountReq{
		AccountId: req.AccountId,
	})
	if err != nil {
		return &types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "admin_account", req.AccountId, "删除管理员账号")
	}
	return resp, nil
}
