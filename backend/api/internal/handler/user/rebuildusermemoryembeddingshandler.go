package user

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// RebuildUserMemoryEmbeddingsHandler 手动重建记忆向量索引（Phase 2 学习/重索引）。
func RebuildUserMemoryEmbeddingsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing or invalid authorization header"))
			return
		}
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		userID, err := utils.GetUserIDFromToken(tokenString)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := user.NewRebuildUserMemoryEmbeddingsLogic(r.Context(), svcCtx)
		resp, err := l.RebuildUserMemoryEmbeddings(strconv.Itoa(int(userID)))
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
