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

func GetVipHistoryHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetVipHistoryReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetVipRecords(r.Context(), &moe.GetVipRecordsReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetVipHistoryResp{
				BaseResp: common.HandleRPCError(err, ""),
				Data:     nil,
				Total:    0,
			})
			return
		}

		respRecords := make([]types.VipRecord, 0, len(rpcResp.Records))
		for _, record := range rpcResp.Records {
			respRecords = append(respRecords, types.VipRecord{
				Id:        record.Id,
				UserId:    record.UserId,
				PlanId:    record.PlanId,
				PlanName:  record.PlanName,
				StartAt:   record.StartAt,
				EndAt:     record.EndAt,
				Status:    record.Status,
				CreatedAt: record.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetVipHistoryResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP历史记录成功"),
			Data:     respRecords,
			Total:    int(rpcResp.Total),
		})
	}
}
