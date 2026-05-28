package checkin

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CheckInHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CheckInReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CheckInGW.CheckIn(r.Context(), &moe.CheckInReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CheckInResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CheckInResp{
			BaseResp: types.BaseResp{Code: 0, Message: "签到成功", Success: true},
			Data: types.CheckInData{
				ExpGained:       int(rpcResp.ExpGained),
				NewLevel:        int(rpcResp.NewLevel),
				ConsecutiveDays: int(rpcResp.ConsecutiveDays),
				LevelUp:         rpcResp.LevelUp,
				SpecialReward:   rpcResp.SpecialReward,
				NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
			},
		})
	}
}
