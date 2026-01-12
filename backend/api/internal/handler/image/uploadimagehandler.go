package image

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
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

		// 确保本地图片目录存在
		if err := os.MkdirAll(localImgDir, os.ModePerm); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 生成唯一文件名，避免覆盖
		timestamp := time.Now().Unix()
		filename := fmt.Sprintf("%d_%s", timestamp, fileHeader.Filename)
		imgPath := filepath.Join(localImgDir, filename)

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
		imgUrl := fmt.Sprintf("%s/api/images/%s", localServerUrl, filename)

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
