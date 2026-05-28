package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAuditLogsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAuditLogsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAuditLogsLogic {
	return &AdminListAuditLogsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAuditLogsLogic) AdminListAuditLogs(req *types.AdminListAuditLogsReq) (*types.AdminListAuditLogsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAuditLogs(l.ctx, &moe.AdminListAuditLogsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Action:   req.Action,
		Resource: req.Resource,
		AdminId:  req.AdminId,
	})
	if err != nil {
		return &types.AdminListAuditLogsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAuditLogItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminAuditLogToTypes(item)
	}
	return &types.AdminListAuditLogsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListAuditLogsData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
