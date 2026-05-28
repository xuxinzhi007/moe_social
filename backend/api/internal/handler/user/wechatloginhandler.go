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

func WechatLoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.WechatLoginReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.WechatLogin(r.Context(), &moe.WechatLoginReq{
			Code: strings.TrimSpace(req.Code),
			Flow: strings.TrimSpace(req.Flow),
		})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.WechatLoginResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		resp := &types.WechatLoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.GetUser() != nil {
			resp.Data = types.WechatLoginData{
				User:      common.RpcUserToTypes(rpcResp.GetUser()),
				Token:     rpcResp.GetToken(),
				IsNewUser: rpcResp.GetIsNewUser(),
			}
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
