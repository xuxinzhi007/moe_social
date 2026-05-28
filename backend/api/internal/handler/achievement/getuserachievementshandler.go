package achievement

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserAchievementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserAchievementsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.AchievementGW.GetUserAchievements(r.Context(), &moe.GetUserAchievementsReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserAchievementsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取成就列表成功", Success: true},
			Data:     handlerutil.BadgesFromRPC(rpcResp.Badges),
		})
	}
}
