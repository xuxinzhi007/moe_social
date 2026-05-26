package moe

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetMoeToolsSchemaLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetMoeToolsSchemaLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetMoeToolsSchemaLogic {
	return &GetMoeToolsSchemaLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetMoeToolsSchemaLogic) GetMoeToolsSchema() (*types.MoeToolSchemaResp, error) {
	rawTools := tools.OpenAISchemaList()
	toolsOut := make([]interface{}, 0, len(rawTools))
	for _, item := range rawTools {
		toolsOut = append(toolsOut, item)
	}
	return &types.MoeToolSchemaResp{
		BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
		Data: types.MoeToolSchemaData{
			Tools: toolsOut,
			Tier:  string(core.DefaultTier),
		},
	}, nil
}
