package community

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"backend/api/internal/logic/community"
	"backend/api/internal/svc"
	"backend/api/internal/types"
)

func JoinGroupHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.JoinGroupReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.Error(w, err)
			return
		}

		l := community.NewJoinGroupLogic(r.Context(), svcCtx)
		resp, err := l.JoinGroup(&req)
		if err != nil {
			httpx.Error(w, err)
		} else {
			httpx.OkJson(w, resp)
		}
	}
}
