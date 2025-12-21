package user

import (
	"encoding/json"
	"fmt"
	"net/http"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 自定义解析，允许username或email为空
		var req types.LoginReq

		// 使用标准库json.Unmarshal解析，绕过go-zero的严格验证
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		// 验证password必须存在
		if req.Password == "" {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("password is required"))
			return
		}

		// 验证username或email至少存在一个
		if req.Username == "" && req.Email == "" {
			httpx.ErrorCtx(r.Context(), w, fmt.Errorf("username or email is required"))
			return
		}

		l := user.NewLoginLogic(r.Context(), svcCtx)
		resp, err := l.Login(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
