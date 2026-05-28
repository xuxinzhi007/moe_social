package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserActiveVipRecordHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserActiveVipRecordReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserActiveVipRecord(r.Context(), &moe.GetUserActiveVipRecordReq{UserId: req.UserId})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserActiveVipRecordResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserActiveVipRecordResp{
			BaseResp: common.HandleRPCError(nil, "获取用户活跃VIP记录成功"),
			Data: types.VipRecord{
				Id:        rpcResp.Record.Id,
				UserId:    rpcResp.Record.UserId,
				PlanId:    rpcResp.Record.PlanId,
				PlanName:  rpcResp.Record.PlanName,
				StartAt:   rpcResp.Record.StartAt,
				EndAt:     rpcResp.Record.EndAt,
				Status:    rpcResp.Record.Status,
				CreatedAt: rpcResp.Record.CreatedAt,
			},
		})
	}
}
