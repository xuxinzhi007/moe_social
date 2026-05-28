//go:build hybrid

package emoji

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetEmojiPackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetEmojiPackReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		emojiPack := types.EmojiPack{
			Id:          req.PackId,
			Name:        "可爱猫咪",
			Description: "可爱的猫咪表情包",
			AuthorName:  "系统管理员",
			Category:    "animals",
			Price:       0,
			IsFree:      true,
			CoverImage:  "https://picsum.photos/300/200?random=1",
			Emojis: []types.Emoji{
				{
					Id:         "1-1",
					ImageUrl:   "https://picsum.photos/100/100?random=2",
					Tags:       []string{"cat", "cute"},
					IsAnimated: false,
				},
				{
					Id:         "1-2",
					ImageUrl:   "https://picsum.photos/100/100?random=3",
					Tags:       []string{"cat", "happy"},
					IsAnimated: false,
				},
			},
			DownloadCount: 1000,
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetEmojiPackResp{
			BaseResp: common.HandleError(nil),
			Data:     emojiPack,
		})
	}
}
