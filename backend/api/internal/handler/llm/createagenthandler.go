package llm

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CreateAgentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LlmCreateAgentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.OkJson(w, common.HandleError(err))
			return
		}

		l := llm.NewCreateAgentLogic(r.Context(), svcCtx)
		resp, err := l.CreateAgent(&req)
		if err != nil {
			httpx.OkJson(w, common.HandleError(err))
		} else {
			httpx.OkJson(w, resp)
		}
	}
}

