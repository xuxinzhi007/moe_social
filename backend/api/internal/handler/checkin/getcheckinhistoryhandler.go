//go:build hybrid

package checkin

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetCheckInHistoryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetCheckInHistoryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CheckInGW.GetCheckInHistory(r.Context(), &moe.GetCheckInHistoryReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetCheckInHistoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		records := make([]types.CheckInRecord, 0, len(rpcResp.Records))
		for _, record := range rpcResp.Records {
			records = append(records, types.CheckInRecord{
				CheckInDate:       record.CheckInDate,
				ConsecutiveDays:   int(record.ConsecutiveDays),
				ExpReward:         int(record.ExpReward),
				IsSpecialReward:   record.IsSpecialReward,
				SpecialRewardDesc: record.SpecialRewardDesc,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetCheckInHistoryResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取签到历史成功", Success: true},
			Data:     records,
			Total:    int(rpcResp.Total),
		})
	}
}
