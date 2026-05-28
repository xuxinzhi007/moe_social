package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminUpdateAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateAccountReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateAccountReq) (*types.AdminUpdateAccountResp, error) {
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
			rpcResp, err := svcCtx.AdminGW.AdminUpdateAccount(ctx, rpcReq)
			if err != nil {
			return &types.AdminUpdateAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminUpdateAccountResp{
			BaseResp: common.HandleRPCError(nil, "更新成功"),
			Data:     common.RpcAdminAccountToTypes(rpcResp.GetAccount()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "admin_account", req.AccountId, "更新管理员账号")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
