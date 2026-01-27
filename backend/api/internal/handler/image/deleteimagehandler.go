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

func DeleteImageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, err := mustParseClaims(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var req types.DeleteImageReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		imgDir := strings.TrimSpace(svcCtx.Config.Image.LocalDir)
		if imgDir == "" {
			imgDir = "./data/images"
		}

		// 只允许删除自己的文件：key 里的 folder 必须匹配当前用户 folder
		expectedFolder := folderNameForUser(claims.UserID, claims.Username)
		folder, filename, ok := splitImageKey(req.Filename)
		if !ok || folder != expectedFolder {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		folder = filepath.Base(folder)
		filename = filepath.Base(filename)
		imgPath := filepath.Join(imgDir, folder, filename)

		if _, err := os.Stat(imgPath); os.IsNotExist(err) {
			resp := &types.DeleteImageResp{BaseResp: common.HandleError(nil)}
			httpx.OkJsonCtx(r.Context(), w, resp)
			return
		}
		if err := os.Remove(imgPath); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		resp := &types.DeleteImageResp{BaseResp: common.HandleError(nil)}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
