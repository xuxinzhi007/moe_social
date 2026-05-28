package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminListAuditLogsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListAuditLogsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminListAuditLogsReq) (*types.AdminListAuditLogsResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminListAuditLogs(ctx, &moe.AdminListAuditLogsReq{
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
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
