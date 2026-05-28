//go:build hybrid

package checkin

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetExpLogsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetExpLogsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CheckInGW.GetExpLogs(r.Context(), &moe.GetExpLogsReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetExpLogsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		logs := make([]types.ExpLogRecord, 0, len(rpcResp.Logs))
		for _, log := range rpcResp.Logs {
			logs = append(logs, types.ExpLogRecord{
				Id:          log.Id,
				ExpChange:   int(log.ExpChange),
				Source:      log.Source,
				Description: log.Description,
				CreatedAt:   log.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetExpLogsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取经验日志成功", Success: true},
			Data:     logs,
			Total:    int(rpcResp.Total),
		})
	}
}
