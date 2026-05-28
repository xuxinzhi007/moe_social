package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAccountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAccountLogic {
	return &AdminUpdateAccountLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateAccountLogic) AdminUpdateAccount(req *types.AdminUpdateAccountReq) (*types.AdminUpdateAccountResp, error) {
	rpcReq := &moe.AdminUpdateAccountReq{AccountId: req.AccountId}
	if username := strings.TrimSpace(req.Username); username != "" {
		rpcReq.Username = username
		rpcReq.UpdateUsername = true
	}
	if password := strings.TrimSpace(req.Password); password != "" {
		rpcReq.Password = password
		rpcReq.UpdatePassword = true
	}
	if role := strings.TrimSpace(req.Role); role != "" {
		rpcReq.Role = role
		rpcReq.UpdateRole = true
	}
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateAccount(l.ctx, rpcReq)
	if err != nil {
		return &types.AdminUpdateAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpdateAccountResp{
		BaseResp: common.HandleRPCError(nil, "更新成功"),
		Data:     common.RpcAdminAccountToTypes(rpcResp.GetAccount()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "admin_account", req.AccountId, "更新管理员账号")
	}
	return resp, nil
}
