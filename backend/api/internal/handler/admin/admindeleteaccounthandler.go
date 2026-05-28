package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteAccountReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteAccountReq) (*types.AdminDeleteAccountResp, error) {
			_, err := svcCtx.AdminGW.AdminDeleteAccount(ctx, &moe.AdminDeleteAccountReq{
			AccountId: req.AccountId,
			})
			if err != nil {
			return &types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp := &types.AdminDeleteAccountResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "admin_account", req.AccountId, "删除管理员账号")
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
