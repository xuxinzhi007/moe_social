package post

import (
	"fmt"
	"net/http"
	"strings"

	postlogic "backend/api/internal/logic/post"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdatePostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, err := parseJWTClaims(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var req types.UpdatePostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		req.UserId = fmt.Sprintf("%d", claims.UserID)

		l := postlogic.NewUpdatePostLogic(r.Context(), svcCtx)
		resp, err := l.UpdatePost(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}

// parseJWTClaims 从 Authorization header 解析 JWT。
func parseJWTClaims(r *http.Request) (*utils.CustomClaims, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	token := ""
	if strings.HasPrefix(auth, "Bearer ") {
		token = strings.TrimPrefix(auth, "Bearer ")
	} else {
		token = r.URL.Query().Get("token")
	}
	if token == "" {
		return nil, fmt.Errorf("unauthorized")
	}
	return utils.ParseToken(token)
}
