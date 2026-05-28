package user

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func RechargeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.RechargeReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.UserGW.Recharge(r.Context(), &moe.RechargeReq{
			UserId:      req.UserId,
			Amount:      float32(req.Amount),
			Description: req.Description,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.RechargeResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "充值成功",
				Success: true,
			},
			Data: types.Transaction{
				UserId:      req.UserId,
				Type:        "recharge",
				Amount:      req.Amount,
				Description: req.Description,
				Status:      "success",
			},
		})
	}
}
