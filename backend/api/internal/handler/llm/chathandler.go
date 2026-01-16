package llm

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"
	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func ChatHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LlmChatReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString := strings.TrimPrefix(authHeader, "Bearer ")
			userID, err := utils.GetUserIDFromToken(tokenString)
			if err != nil {
				logx.Errorf("parse chat jwt failed: %v", err)
			} else {
				logx.Infof("llm chat with jwt user_id=%d, model=%s, messages=%d", userID, req.Model, len(req.Messages))
				ctx := context.WithValue(r.Context(), "user_id", strconv.Itoa(int(userID)))
				r = r.WithContext(ctx)
			}
		} else {
			logx.Infof("llm chat without jwt, model=%s, messages=%d", req.Model, len(req.Messages))
		}

		l := llm.NewChatLogic(r.Context(), svcCtx)
		resp, err := l.Chat(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
