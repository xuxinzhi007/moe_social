package moe

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetMoeToolsSchemaHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	_ = svcCtx
	return func(w http.ResponseWriter, r *http.Request) {
		rawTools := tools.OpenAISchemaList()
		toolsOut := make([]interface{}, 0, len(rawTools))
		for _, item := range rawTools {
			toolsOut = append(toolsOut, item)
		}
		httpx.OkJsonCtx(r.Context(), w, &types.MoeToolSchemaResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.MoeToolSchemaData{
				Tools: toolsOut,
				Tier:  string(core.DefaultTier),
			},
		})
	}
}
