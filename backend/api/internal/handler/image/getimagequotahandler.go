package image

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetImageQuotaHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, err := mustParseClaims(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		imgDir := strings.TrimSpace(svcCtx.Config.Image.LocalDir)
		if imgDir == "" {
			imgDir = "./data/images"
		}

		userFolder := folderNameForUser(claims.UserID, claims.Username)
		userDir := filepath.Join(imgDir, userFolder)

		var used int64 = 0
		count := 0

		entries, err := os.ReadDir(userDir)
		if err == nil {
			for _, e := range entries {
				if e.IsDir() {
					continue
				}
				info, err := e.Info()
				if err != nil {
					continue
				}
				used += info.Size()
				count++
			}
		}

		max := svcCtx.Config.Image.MaxBytes
		var remaining int64 = 0
		if max > 0 {
			remaining = max - used
			if remaining < 0 {
				remaining = 0
			}
		}

		resp := &types.GetImageQuotaResp{
			BaseResp: common.HandleError(nil),
			Data: types.ImageQuota{
				UsedBytes:      used,
				MaxBytes:       max,
				RemainingBytes: remaining,
				Count:          count,
			},
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

