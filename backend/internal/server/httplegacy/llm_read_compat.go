package httplegacy

import (
	"context"
	"net/http"
	"time"

	"backend/internal/apilegacy/common"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterLlmReadCompat LLM 只读 HTTP（PK-3：models / local-models catalog）。
func RegisterLlmReadCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/llm/models", llmModels(svcCtx))
	r.GET("/api/llm/local-models/catalog", llmLocalModelsCatalog(svcCtx))
}

func llmModels(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if models, found := svcCtx.ModelCache.Get(); found {
			return ctx.JSON(http.StatusOK, types.LlmModelsResp{
				BaseResp: common.HandleError(nil),
				Models:   models,
			})
		}
		var names []string
		var err error
		if svcCtx.LLMApp != nil {
			names, err = svcCtx.LLMApp.ListModels(ctx)
		} else {
			cfg, cfgErr := inferenceConfigFromSvc(svcCtx)
			if cfgErr != nil {
				return ctx.JSON(http.StatusOK, types.LlmModelsResp{BaseResp: common.HandleError(cfgErr)})
			}
			tctx, cancel := context.WithTimeout(ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
			defer cancel()
			client := utils.NewHTTPClient(cfg.TimeoutSeconds)
			names, err = common.ListModelNames(tctx, client, cfg)
		}
		if err != nil {
			return ctx.JSON(http.StatusOK, types.LlmModelsResp{BaseResp: common.HandleError(err)})
		}
		svcCtx.ModelCache.Set(names)
		return ctx.JSON(http.StatusOK, types.LlmModelsResp{
			BaseResp: common.HandleError(nil),
			Models:   names,
		})
	}
}

func llmLocalModelsCatalog(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var items []types.LlmLocalModelCatalogItem
		if svcCtx.LLMApp != nil {
			catalog, err := svcCtx.LLMApp.LocalCatalog()
			if err != nil {
				return ctx.JSON(http.StatusOK, types.LlmLocalModelsCatalogResp{BaseResp: common.HandleError(err)})
			}
			items = make([]types.LlmLocalModelCatalogItem, 0, len(catalog))
			for _, item := range catalog {
				items = append(items, types.LlmLocalModelCatalogItem{
					Id: item.ID, Name: item.Name, Filename: item.Filename,
					SizeBytes: item.SizeBytes, Sha256: item.Sha256, Description: item.Description,
					ParametersB: item.ParametersB, Recommended: item.Recommended, DownloadPath: item.DownloadPath,
				})
			}
		} else {
			legacy, err := common.LoadLocalModelCatalog(svcCtx.Config.LocalModels)
			if err != nil {
				return ctx.JSON(http.StatusOK, types.LlmLocalModelsCatalogResp{BaseResp: common.HandleError(err)})
			}
			items = make([]types.LlmLocalModelCatalogItem, 0, len(legacy))
			for _, item := range legacy {
				name := item.Name
				if name == "" {
					name = item.ID
				}
				items = append(items, types.LlmLocalModelCatalogItem{
					Id: item.ID, Name: name, Filename: item.Filename,
					SizeBytes: item.SizeBytes, Sha256: item.Sha256, Description: item.Description,
					ParametersB: item.ParametersB, Recommended: item.Recommended,
					DownloadPath: "/api/llm/local-models/" + item.ID + "/download",
				})
			}
		}
		return ctx.JSON(http.StatusOK, types.LlmLocalModelsCatalogResp{
			BaseResp: common.HandleError(nil),
			Items:    items,
		})
	}
}

func inferenceConfigFromSvc(svcCtx *svc.ServiceContext) (common.InferenceConfig, error) {
	if svcCtx == nil {
		return common.InferenceConfig{}, nil
	}
	return common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
}
