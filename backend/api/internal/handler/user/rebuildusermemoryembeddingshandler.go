package user

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/svc"
	"backend/rpc/pb/moe"
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

		userIDStr := strconv.Itoa(int(userID))
		if userIDStr == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("user_id 不能为空"))
			return
		}

		resp, err := svcCtx.LLMGW.RebuildUserMemoryEmbeddings(r.Context(), &moe.RebuildUserMemoryEmbeddingsReq{
			UserId: userIDStr,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, map[string]interface{}{
			"indexed":  resp.Indexed,
			"provider": resp.Provider,
			"model":    resp.Model,
		})
	}
}
