package user

import (
	"encoding/json"
	"net/http"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func ResetPasswordHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ResetPasswordReq
		// 自定义解析
		decoder := json.NewDecoder(r.Body)
		if err := decoder.Decode(&req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := user.NewResetPasswordLogic(r.Context(), svcCtx)
		resp, err := l.ResetPassword(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}


