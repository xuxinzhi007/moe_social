// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package achievement

import (
	"net/http"

	"backend/api/internal/logic/achievement"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserUnlockedAchievementsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserUnlockedAchievementsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := achievement.NewGetUserUnlockedAchievementsLogic(r.Context(), svcCtx)
		resp, err := l.GetUserUnlockedAchievements(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
