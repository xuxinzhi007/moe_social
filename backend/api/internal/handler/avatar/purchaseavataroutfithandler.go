package avatar

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func PurchaseAvatarOutfitHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.PurchaseAvatarOutfitReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.PurchaseAvatarOutfitResp{
			BaseResp: common.HandleError(nil),
			Data:     "purchase_123456",
		})
	}
}
