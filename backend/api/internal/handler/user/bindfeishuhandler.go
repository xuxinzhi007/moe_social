//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func BindFeishuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.BindFeishuReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := common.UserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.BindFeishu(r.Context(), &moe.BindFeishuReq{
			UserId:      userID,
			FeishuEmail: req.FeishuEmail,
		})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.BindFeishuResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.BindFeishuResp{
			BaseResp: common.HandleRPCError(nil, "飞书绑定成功"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
