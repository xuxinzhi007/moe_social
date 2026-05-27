package llm

import (
	"context"
	"fmt"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type LocalModelsCatalogLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLocalModelsCatalogLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LocalModelsCatalogLogic {
	return &LocalModelsCatalogLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LocalModelsCatalogLogic) LocalModelsCatalog(_ *types.EmptyReq) (*types.LlmLocalModelsCatalogResp, error) {
	var items []types.LlmLocalModelCatalogItem
	if l.svcCtx.LLMApp != nil {
		catalog, err := l.svcCtx.LLMApp.LocalCatalog()
		if err != nil {
			return &types.LlmLocalModelsCatalogResp{
				BaseResp: common.HandleError(err),
				Items:    nil,
			}, nil
		}
		items = make([]types.LlmLocalModelCatalogItem, 0, len(catalog))
		for _, item := range catalog {
			items = append(items, types.LlmLocalModelCatalogItem{
				Id:           item.ID,
				Name:         item.Name,
				Filename:     item.Filename,
				SizeBytes:    item.SizeBytes,
				Sha256:       item.Sha256,
				Description:  item.Description,
				ParametersB:  item.ParametersB,
				Recommended:  item.Recommended,
				DownloadPath: item.DownloadPath,
			})
		}
	} else {
		legacy, err := common.LoadLocalModelCatalog(l.svcCtx.Config.LocalModels)
		if err != nil {
			return &types.LlmLocalModelsCatalogResp{
				BaseResp: common.HandleError(err),
				Items:    nil,
			}, nil
		}
		items = make([]types.LlmLocalModelCatalogItem, 0, len(legacy))
		for _, item := range legacy {
			name := item.Name
			if name == "" {
				name = item.ID
			}
			items = append(items, types.LlmLocalModelCatalogItem{
				Id:           item.ID,
				Name:         name,
				Filename:     item.Filename,
				SizeBytes:    item.SizeBytes,
				Sha256:       item.Sha256,
				Description:  item.Description,
				ParametersB:  item.ParametersB,
				Recommended:  item.Recommended,
				DownloadPath: fmt.Sprintf("/api/llm/local-models/%s/download", item.ID),
			})
		}
	}

	return &types.LlmLocalModelsCatalogResp{
		BaseResp: common.HandleError(nil),
		Items:    items,
	}, nil
}
