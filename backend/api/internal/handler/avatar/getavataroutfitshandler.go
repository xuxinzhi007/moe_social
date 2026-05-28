//go:build hybrid

package avatar

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetAvatarOutfitsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetAvatarOutfitsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		outfits := []types.AvatarOutfit{
			{
				Id:          "1",
				Name:        "休闲服装",
				Description: "舒适的休闲服装",
				Category:    "clothes",
				Style:       "casual",
				Price:       0,
				IsFree:      true,
				ImageUrl:    "https://picsum.photos/200/200?random=4",
				Parts: []types.OutfitPart{
					{
						Id:       "1-1",
						Type:     "top",
						ImageUrl: "https://picsum.photos/150/150?random=5",
					},
					{
						Id:       "1-2",
						Type:     "bottom",
						ImageUrl: "https://picsum.photos/150/150?random=6",
					},
				},
				CreatedAt: "2026-01-12",
			},
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetAvatarOutfitsResp{
			BaseResp: common.HandleError(nil),
			Data:     outfits,
			Total:    len(outfits),
		})
	}
}
