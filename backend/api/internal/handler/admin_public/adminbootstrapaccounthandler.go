//go:build hybrid

package admin_public

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminBootstrapAccountHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.AdminGW.AdminBootstrapAccount(r.Context(), &moe.AdminBootstrapAccountReq{})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminBootstrapAccountResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}
		msg := "管理员账号已存在，未创建"
		if rpcResp.GetCreated() > 0 {
			msg = "已创建默认超管，请尽快登录并修改密码"
		}
		httpx.OkJsonCtx(r.Context(), w, &types.AdminBootstrapAccountResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapAccountData{Created: int(rpcResp.GetCreated())},
		})
	}
}
