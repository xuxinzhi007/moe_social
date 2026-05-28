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

func UnfollowUserHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UnfollowUserReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.UnfollowUser(r.Context(), &moe.UnfollowUserReq{
			UserId:      req.UserId,
			FollowingId: req.FollowingId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.FollowUserResp{
				BaseResp: common.HandleUserGWError(err, ""),
				Data:     false,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.FollowUserResp{
			BaseResp: common.HandleError(nil),
			Data:     rpcResp.Success,
		})
	}
}
