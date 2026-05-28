//go:build hybrid

package achievement

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserAchievementSummaryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserAchievementSummaryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.AchievementGW.GetUserAchievementSummary(r.Context(), &moe.GetUserAchievementSummaryReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserAchievementSummaryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		s := rpcResp.Summary
		httpx.OkJsonCtx(r.Context(), w, &types.GetUserAchievementSummaryResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取成就概览成功", Success: true},
			Data: types.AchievementSummary{
				TotalBadges:          int(s.TotalBadges),
				UnlockedBadges:       int(s.UnlockedBadges),
				CompletionPercentage: s.CompletionPercentage,
			},
		})
	}
}
