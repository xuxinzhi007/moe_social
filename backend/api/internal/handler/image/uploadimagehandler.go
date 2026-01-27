package image

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UploadImageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 设置最大上传文件大小，这里设100M
		r.ParseMultipartForm(100 << 20)

		// 获取上传的文件
		file, fileHeader, err := r.FormFile("file")
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer file.Close()

		imgDir := strings.TrimSpace(svcCtx.Config.Image.LocalDir)
		if imgDir == "" {
			imgDir = "./data/images"
		}

		// 确保本地图片目录存在
		if err := os.MkdirAll(imgDir, os.ModePerm); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 生成唯一文件名，避免覆盖
		timestamp := time.Now().Unix()
		orig := filepath.Base(fileHeader.Filename)
		filename := fmt.Sprintf("%d_%s", timestamp, orig)
		imgPath := filepath.Join(imgDir, filename)

		// 创建文件并写入内容
		outFile, err := os.Create(imgPath)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		defer outFile.Close()

		// 复制文件内容
		if _, err := io.Copy(outFile, file); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 获取文件信息
		fileInfo, err := outFile.Stat()
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 生成图片访问URL
		base := strings.TrimRight(strings.TrimSpace(svcCtx.Config.Image.PublicBaseUrl), "/")
		if base == "" {
			scheme := "http"
			if r.TLS != nil {
				scheme = "https"
			}
			base = fmt.Sprintf("%s://%s", scheme, r.Host)
		}
		imgUrl := fmt.Sprintf("%s/api/images/%s", base, filename)

		// 构建响应
		imageInfo := types.ImageInfo{
			Id:        filename,
			Filename:  filename,
			Url:       imgUrl,
			Size:      fileInfo.Size(),
			CreatedAt: time.Now().Format("2006-01-02 15:04:05"),
		}

		// 返回响应
		resp := &types.UploadImageResp{
			BaseResp: common.HandleError(nil),
			Data:     imageInfo,
		}

		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
