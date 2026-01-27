package image

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetImageListHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, err := mustParseClaims(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var req types.GetImageListReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 只返回当前用户的图片列表
		imgDir := strings.TrimSpace(svcCtx.Config.Image.LocalDir)
		if imgDir == "" {
			imgDir = "./data/images"
		}

		userFolder := folderNameForUser(claims.UserID, claims.Username)
		userDir := filepath.Join(imgDir, userFolder)

		files, err := os.ReadDir(userDir)
		if err != nil {
			// 目录不存在视为无图片
			resp := &types.GetImageListResp{
				BaseResp: common.HandleError(nil),
				Data:     []types.ImageInfo{},
				Total:    0,
			}
			httpx.OkJsonCtx(r.Context(), w, resp)
			return
		}

		base := strings.TrimRight(strings.TrimSpace(svcCtx.Config.Image.PublicBaseUrl), "/")
		if base == "" {
			scheme := "http"
			if r.TLS != nil {
				scheme = "https"
			}
			base = fmt.Sprintf("%s://%s", scheme, r.Host)
		}

		imageInfos := make([]types.ImageInfo, 0, len(files))
		for _, f := range files {
			if f.IsDir() {
				continue
			}
			info, err := f.Info()
			if err != nil {
				continue
			}
			filename := f.Name()
			key := fmt.Sprintf("%s__%s", userFolder, filename)
			imageInfos = append(imageInfos, types.ImageInfo{
				Id:        key,
				Filename:  key,
				Url:       fmt.Sprintf("%s/api/images/%s", base, key),
				Size:      info.Size(),
				CreatedAt: info.ModTime().Format("2006-01-02 15:04:05"),
			})
		}

		sort.Slice(imageInfos, func(i, j int) bool {
			return imageInfos[i].CreatedAt > imageInfos[j].CreatedAt
		})

		// default values
		if req.Page <= 0 {
			req.Page = 1
		}
		if req.PageSize <= 0 {
			req.PageSize = 10
		}

		total := len(imageInfos)
		start := (req.Page - 1) * req.PageSize
		end := start + req.PageSize
		if start > total {
			start = total
		}
		if end > total {
			end = total
		}

		var paginated []types.ImageInfo
		if start < total {
			paginated = imageInfos[start:end]
		} else {
			paginated = []types.ImageInfo{}
		}

		resp := &types.GetImageListResp{
			BaseResp: common.HandleError(nil),
			Data:     paginated,
			Total:    total,
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
