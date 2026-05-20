package user

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// SearchUserMemoriesHandler 记忆文本库检索（编排层 / memory_search 工具共用）。
func SearchUserMemoriesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SearchUserMemoriesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

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
		req.UserId = strconv.Itoa(int(userID))

		l := user.NewSearchUserMemoriesLogic(r.Context(), svcCtx)
		resp, err := l.SearchUserMemories(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
