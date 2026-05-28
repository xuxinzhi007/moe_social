package content

import (
	"fmt"
	"net/http"
	"time"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/google/uuid"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func GenerateContentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ContentGenerationReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		contentId := uuid.New().String()
		createdAt := time.Now().Format(time.RFC3339)

		var url, content string
		switch req.Type {
		case "text":
			content = fmt.Sprintf("生成的文本内容: %s", req.Prompt)
		case "image":
			url = fmt.Sprintf("https://example.com/images/%s.jpg", contentId)
		case "video":
			url = fmt.Sprintf("https://example.com/videos/%s.mp4", contentId)
		default:
			httpx.OkJsonCtx(r.Context(), w, &types.ContentGenerationResp{
				BaseResp: types.BaseResp{
					Code:    400,
					Message: "不支持的内容类型",
					Success: false,
				},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.ContentGenerationResp{
			BaseResp: types.BaseResp{
				Code:    200,
				Message: "内容生成成功",
				Success: true,
			},
			Data: struct {
				Id        string `json:"id"`
				Type      string `json:"type"`
				Url       string `json:"url,optional"`
				Content   string `json:"content,optional"`
				CreatedAt string `json:"created_at"`
			}{
				Id:        contentId,
				Type:      req.Type,
				Url:       url,
				Content:   content,
				CreatedAt: createdAt,
			},
		})
	}
}
