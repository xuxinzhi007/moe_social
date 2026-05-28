//go:build hybrid

package user

import (
	"errors"
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CheckUserByEmailHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserByEmailReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if req.Email == "" {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserByEmailResp{
				BaseResp: common.HandleError(errors.New("邮箱不能为空")),
			})
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserByEmail(r.Context(), &moe.GetUserByEmailReq{Email: req.Email})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserByEmailResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserByEmailResp{
			BaseResp: common.HandleRPCError(nil, "查询成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
