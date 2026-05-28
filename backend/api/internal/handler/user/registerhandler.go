package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func RegisterHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.RegisterReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.Register(r.Context(), &moe.RegisterReq{
			Username: req.Username,
			Password: req.Password,
			Email:    req.Email,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.RegisterResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		resp := &types.RegisterResp{BaseResp: common.HandleRPCError(nil, "注册成功")}
		if rpcResp.User != nil {
			resp.Data = types.RegisterData{
				User:  common.RpcUserToTypes(rpcResp.User),
				Token: rpcResp.Token,
			}
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
