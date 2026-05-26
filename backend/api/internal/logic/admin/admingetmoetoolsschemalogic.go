package admin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"
	"backend/pkg/moe/toolaudit"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeToolsSchemaLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeToolsSchemaLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeToolsSchemaLogic {
	return &AdminGetMoeToolsSchemaLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetMoeToolsSchemaLogic) AdminGetMoeToolsSchema(_ *types.EmptyReq) (*types.AdminGetMoeToolsSchemaResp, error) {
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
}
