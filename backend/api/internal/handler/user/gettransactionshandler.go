//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetTransactionsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetTransactionsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetTransactions(r.Context(), &moe.GetTransactionsReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		transactions := make([]types.Transaction, 0)
		for _, t := range rpcResp.Transactions {
			transactions = append(transactions, types.Transaction{
				Id:          t.Id,
				UserId:      t.UserId,
				Type:        t.Type,
				Amount:      float64(t.Amount),
				Description: t.Description,
				Status:      t.Status,
				CreatedAt:   t.CreatedAt,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetTransactionsResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "获取交易记录成功",
				Success: true,
			},
			Data:  transactions,
			Total: int(rpcResp.Total),
		})
	}
}
