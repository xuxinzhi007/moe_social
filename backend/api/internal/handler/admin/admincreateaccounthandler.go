//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminCreateAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminCreateAccountReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminCreateAccountReq) (*types.AdminCreateAccountResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminCreateAccount(ctx, &moe.AdminCreateAccountReq{
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
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "admin_account", resp.Data.Id, "创建管理员账号")
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
