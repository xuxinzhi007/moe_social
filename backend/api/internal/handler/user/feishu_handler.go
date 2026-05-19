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

func authUserID(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return "", errors.New("missing or invalid authorization header")
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	userID, err := utils.GetUserIDFromToken(tokenString)
	if err != nil {
		return "", err
	}
	return strconv.Itoa(int(userID)), nil
}

func BindFeishuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.BindFeishuReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		userID, err := authUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := user.NewFeishuLogic(r.Context(), svcCtx)
		resp, err := l.Bind(userID, req.FeishuEmail)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func UnbindFeishuHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := authUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := user.NewFeishuLogic(r.Context(), svcCtx)
		resp, err := l.Unbind(userID)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func SendFeishuTestCardHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, err := authUserID(r)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := user.NewFeishuLogic(r.Context(), svcCtx)
		resp, err := l.SendTestCard(userID)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
