//go:build hybrid

package llm

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// LocalModelDownloadHandler streams a GGUF file to the mobile app (supports Range resume).
func LocalModelDownloadHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := extractLocalModelIDFromPath(r.URL.Path)
		if id == "" {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("model id is required"))
			return
		}

		meta, err := common.FindLocalModelByID(svcCtx.Config.LocalModels, id)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		f, err := os.Open(meta.FilePath)
		if err != nil {
			logx.Errorf("open local model file failed: %v", err)
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("model file unavailable"))
			return
		}
		defer f.Close()

		st, err := f.Stat()
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		size := st.Size()

		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, meta.Filename))
		if meta.Sha256 != "" {
			w.Header().Set("X-Model-Sha256", meta.Sha256)
		}

		rangeHeader := r.Header.Get("Range")
		if rangeHeader == "" {
			w.Header().Set("Content-Length", strconv.FormatInt(size, 10))
			w.WriteHeader(http.StatusOK)
			_, _ = io.Copy(w, f)
			return
		}

		start, end, err := common.ParseHTTPByteRange(rangeHeader, size)
		if err != nil {
			w.Header().Set("Content-Range", fmt.Sprintf("bytes */%d", size))
			http.Error(w, "invalid range", http.StatusRequestedRangeNotSatisfiable)
			return
		}

		if _, err := f.Seek(start, io.SeekStart); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		contentLen := end - start + 1
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, size))
		w.Header().Set("Content-Length", strconv.FormatInt(contentLen, 10))
		w.WriteHeader(http.StatusPartialContent)
		_, _ = io.CopyN(w, f, contentLen)
	}
}

func extractLocalModelIDFromPath(path string) string {
	const prefix = "/api/llm/local-models/"
	const suffix = "/download"
	if !strings.HasPrefix(path, prefix) || !strings.HasSuffix(path, suffix) {
		return ""
	}
	mid := strings.TrimSuffix(strings.TrimPrefix(path, prefix), suffix)
	return strings.Trim(mid, "/")
}
