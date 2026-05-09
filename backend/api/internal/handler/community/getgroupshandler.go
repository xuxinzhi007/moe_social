package community

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"backend/api/internal/logic/community"
	"backend/api/internal/svc"
	"backend/api/internal/types"
)

func GetGroupsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetGroupsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.Error(w, err)
			return
		}

		l := community.NewGetGroupsLogic(r.Context(), svcCtx)
		resp, err := l.GetGroups(&req)
		if err != nil {
			httpx.Error(w, err)
		} else {
			httpx.OkJson(w, resp)
		}
	}
}
