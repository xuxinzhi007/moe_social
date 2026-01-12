package avatar

import (
	"net/http"

	"backend/api/internal/logic/avatar"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func PurchaseAvatarOutfitHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.PurchaseAvatarOutfitReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := avatar.NewPurchaseAvatarOutfitLogic(r.Context(), svcCtx)
		resp, err := l.PurchaseAvatarOutfit(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
