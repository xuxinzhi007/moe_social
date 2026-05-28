package gift

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetGiftsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGiftsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.GiftGW.GetGifts(r.Context(), &moe.GetGiftsReq{
			Page:         int32(req.Page),
			PageSize:     int32(req.PageSize),
			ViewerUserId: req.UserId,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetGiftsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Data:     handlerutil.GiftsFromRPC(rpcResp.Gifts),
			Total:    int(rpcResp.Total),
		})
	}
}
