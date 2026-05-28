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

func CheckFollowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CheckFollowReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.CheckFollow(r.Context(), &moe.CheckFollowReq{
			FollowerId:  req.FollowerId,
			FollowingId: req.FollowingId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CheckFollowResp{
				BaseResp: common.HandleUserGWError(err, ""),
				Data:     false,
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CheckFollowResp{
			BaseResp: common.HandleError(nil),
			Data:     rpcResp.IsFollowing,
		})
	}
}
