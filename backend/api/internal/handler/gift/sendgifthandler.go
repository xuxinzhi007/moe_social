//go:build hybrid

package gift

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SendGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.GiftGW.SendGift(r.Context(), &moe.SendGiftReq{
			FromUserId: req.UserId,
			ToUserId:   req.ToUserId,
			GiftId:     req.GiftId,
			Quantity:   int32(req.Quantity),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendGiftResp{
				BaseResp: types.BaseResp{Code: 1, Message: err.Error(), Success: false},
			})
			return
		}

		out := types.SendGiftResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: rpcResp.Message,
				Success: rpcResp.Success,
			},
			NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
		}
		if rpcResp.Success && rpcResp.Record != nil {
			out.Data = handlerutil.GiftRecordFromRPC(rpcResp.Record)
		}
		httpx.OkJsonCtx(r.Context(), w, &out)
	}
}
