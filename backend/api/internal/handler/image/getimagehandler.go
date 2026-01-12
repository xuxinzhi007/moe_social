package image

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetImageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.DeleteImageReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 构建图片文件路径
		imgPath := filepath.Join(localImgDir, req.Filename)

		// 检查文件是否存在
		if _, err := os.Stat(imgPath); os.IsNotExist(err) {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("图片不存在"))
			return
		}

		// 获取文件信息
		fileInfo, err := os.Stat(imgPath)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 设置正确的Content-Type
		contentType := "image/jpeg"
		// 根据文件扩展名设置正确的Content-Type
		ext := filepath.Ext(req.Filename)
		switch ext {
		case ".png":
			contentType = "image/png"
		case ".gif":
			contentType = "image/gif"
		case ".webp":
			contentType = "image/webp"
		case ".svg":
			contentType = "image/svg+xml"
		}

		// 设置响应头
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%s", req.Filename))
		w.Header().Set("Content-Length", fmt.Sprintf("%d", fileInfo.Size()))

		// 打开并读取文件
		file, err := os.Open(imgPath)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer file.Close()

		// 将文件内容写入响应
		if _, err := io.Copy(w, file); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
	}
}
