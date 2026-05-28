//go:build hybrid

package user

import (
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuLoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FeishuLoginReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.FeishuLogin(r.Context(), &moe.FeishuLoginReq{
			Code: strings.TrimSpace(req.Code),
		})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.FeishuLoginResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		resp := &types.FeishuLoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.GetUser() != nil {
			resp.Data = types.FeishuLoginData{
				User:      common.RpcUserToTypes(rpcResp.GetUser()),
				Token:     rpcResp.GetToken(),
				IsNewUser: rpcResp.GetIsNewUser(),
			}
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
