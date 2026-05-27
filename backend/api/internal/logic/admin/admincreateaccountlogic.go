package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateAccountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAccountLogic {
	return &AdminCreateAccountLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminCreateAccountLogic) AdminCreateAccount(req *types.AdminCreateAccountReq) (*types.AdminCreateAccountResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminCreateAccount(l.ctx, &super.AdminCreateAccountReq{
		Username: req.Username,
		Password: req.Password,
		Role:     req.Role,
	})
	if err != nil {
		return &types.AdminCreateAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminCreateAccountResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcAdminAccountToTypes(rpcResp.GetAccount()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "admin_account", resp.Data.Id, "创建管理员账号")
	}
	return resp, nil
}
