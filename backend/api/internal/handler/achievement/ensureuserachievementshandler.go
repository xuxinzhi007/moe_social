package achievement

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func EnsureUserAchievementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EnsureUserAchievementsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.AchievementGW.EnsureUserAchievements(r.Context(), &moe.EnsureUserAchievementsReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.EnsureUserAchievementsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.EnsureUserAchievementsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "成就初始化成功", Success: true},
			Data: types.EnsureUserAchievementsData{
				NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
			},
		})
	}
}
