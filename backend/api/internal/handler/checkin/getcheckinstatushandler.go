//go:build hybrid

package checkin

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetCheckInStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetCheckInStatusReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CheckInGW.GetCheckInStatus(r.Context(), &moe.GetCheckInStatusReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetCheckInStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetCheckInStatusResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取签到状态成功", Success: true},
			Data: types.CheckInStatus{
				HasCheckedToday: rpcResp.Status.HasCheckedToday,
				ConsecutiveDays: int(rpcResp.Status.ConsecutiveDays),
				TodayReward:     int(rpcResp.Status.TodayReward),
				NextDayReward:   int(rpcResp.Status.NextDayReward),
				CanCheckIn:      rpcResp.Status.CanCheckIn,
			},
		})
	}
}
