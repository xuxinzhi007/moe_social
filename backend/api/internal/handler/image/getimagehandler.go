package image

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

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

		imgDir := strings.TrimSpace(svcCtx.Config.Image.LocalDir)
		if imgDir == "" {
			imgDir = "./data/images"
		}

		folder, filename, ok := splitImageKey(req.Filename)
		if !ok {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("图片不存在"))
			return
		}
		// 防止路径穿越
		folder = filepath.Base(folder)
		filename = filepath.Base(filename)

		// 构建图片文件路径
		imgPath := filepath.Join(imgDir, folder, filename)

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

		// 缓存：文件名带时间戳/唯一 key，基本可视为不可变资源
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%s", req.Filename))

		// 打开并读取文件
		file, err := os.Open(imgPath)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer file.Close()

		// 交给 ServeContent：支持 Range、If-Modified-Since/304，滚动预览更顺滑
		http.ServeContent(w, r, filename, fileInfo.ModTime(), file)
	}
}
