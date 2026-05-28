package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UnbindFeishuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := common.UserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, rpcErr := svcCtx.UserGW.UnbindFeishu(r.Context(), &moe.UnbindFeishuReq{UserId: userID})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.UnbindFeishuResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.UnbindFeishuResp{
			BaseResp: common.HandleRPCError(nil, "已解除飞书绑定"),
			Data:     common.RpcUserToTypes(rpcResp.User),
		})
	}
}
