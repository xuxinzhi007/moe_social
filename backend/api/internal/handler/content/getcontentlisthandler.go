package content

import (
	"net/http"
	"time"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetContentListHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ContentListReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		offset := (req.Page - 1) * req.PageSize

		contentItems := []types.ContentItem{
			{
				Id:        "1",
				UserId:    req.UserId,
				Type:      "text",
				Prompt:    "生成一篇关于人工智能的文章",
				Content:   "人工智能是一种模拟人类智能的技术...",
				CreatedAt: time.Now().Add(-24 * time.Hour).Format(time.RFC3339),
			},
			{
				Id:        "2",
				UserId:    req.UserId,
				Type:      "image",
				Prompt:    "生成一张猫咪的图片",
				Url:       "https://example.com/images/cat.jpg",
				CreatedAt: time.Now().Add(-48 * time.Hour).Format(time.RFC3339),
			},
			{
				Id:        "3",
				UserId:    req.UserId,
				Type:      "video",
				Prompt:    "生成一段风景视频",
				Url:       "https://example.com/videos/landscape.mp4",
				CreatedAt: time.Now().Add(-72 * time.Hour).Format(time.RFC3339),
			},
		}

		if req.Type != "" {
			filteredItems := []types.ContentItem{}
			for _, item := range contentItems {
				if item.Type == req.Type {
					filteredItems = append(filteredItems, item)
				}
			}
			contentItems = filteredItems
		}

		total := len(contentItems)

		if offset < len(contentItems) {
			end := offset + req.PageSize
			if end > len(contentItems) {
				end = len(contentItems)
			}
			contentItems = contentItems[offset:end]
		} else {
			contentItems = []types.ContentItem{}
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ContentListResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "获取内容列表成功",
				Success: true,
			},
			Data:  contentItems,
			Total: total,
		})
	}
}
