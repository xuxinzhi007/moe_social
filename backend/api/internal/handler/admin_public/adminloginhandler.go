package admin_public

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminLoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminLoginReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.AdminGW.AdminLogin(r.Context(), &moe.AdminLoginReq{
			Username: req.Username,
			Password: req.Password,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.AdminLoginResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.AdminLoginResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminLoginData{
				Token:    rpcResp.Token,
				AdminId:  rpcResp.AdminId,
				Username: rpcResp.Username,
				Role:     rpcResp.Role,
				ExpireAt: rpcResp.ExpireAt,
			},
		})
	}
}
