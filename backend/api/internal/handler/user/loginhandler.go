//go:build hybrid

package user

import (
	"encoding/json"
	"fmt"
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LoginReq
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		if req.Password == "" {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("password is required"))
			return
		}
		if req.Username == "" && req.Email == "" {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("username or email is required"))
			return
		}

		rpcResp, err := svcCtx.UserGW.Login(r.Context(), &moe.LoginReq{
			Username: req.Username,
			Password: req.Password,
			Email:    req.Email,
		})
		if err != nil {
			logx.WithContext(r.Context()).Errorf("[认证] 登录：调用用户服务失败 错误=%v", err)
			httpx.OkJsonCtx(r.Context(), w, &types.LoginResp{
				BaseResp: common.HandleUserGWError(err, ""),
			})
			return
		}

		resp := &types.LoginResp{BaseResp: common.HandleRPCError(nil, "登录成功")}
		if rpcResp.User != nil {
			resp.Data = types.LoginData{
				User:  common.RpcUserToTypes(rpcResp.User),
				Token: rpcResp.Token,
			}
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
