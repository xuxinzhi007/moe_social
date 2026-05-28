package user

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetTransactionHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetTransactionReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetTransaction(r.Context(), &moe.GetTransactionReq{Id: req.TransactionId})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		t := rpcResp.Transaction
		httpx.OkJsonCtx(r.Context(), w, &types.GetTransactionResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "获取交易详情成功",
				Success: true,
			},
			Data: types.Transaction{
				Id:          t.Id,
				UserId:      t.UserId,
				Type:        t.Type,
				Amount:      float64(t.Amount),
				Description: t.Description,
				Status:      t.Status,
				CreatedAt:   t.CreatedAt,
			},
		})
	}
}
