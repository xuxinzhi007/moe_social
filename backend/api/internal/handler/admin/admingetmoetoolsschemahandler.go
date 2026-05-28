package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/core"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminGetMoeToolsSchemaHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.EmptyReq) (*types.AdminGetMoeToolsSchemaResp, error) {
			items := toolaudit.BuildSchemaItems()
			toolsOut := make([]types.AdminMoeToolSchemaItem, 0, len(items))
			for _, it := range items {
			toolsOut = append(toolsOut, types.AdminMoeToolSchemaItem{
			Name:         it.Name,
			Description:  it.Description,
			AllowedTiers: it.AllowedTiers,
			})
			}
			openai := tools.OpenAISchemaList()
			openaiOut := make([]interface{}, 0, len(openai))
			for _, o := range openai {
			openaiOut = append(openaiOut, o)
			}
			return &types.AdminGetMoeToolsSchemaResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.AdminMoeToolsSchemaData{
			DefaultTier: string(core.DefaultTier),
			Tools:       toolsOut,
			OpenAITools: openaiOut,
			},
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
