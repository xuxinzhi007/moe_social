package llmgrpc

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	llmv1 "backend/api/llm/v1"
)

func (s *Server) GetAiUserConfig(ctx context.Context, _ *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetAiUserConfig(ctx, &llmv1.GetAiUserConfigReq{UserId: userID})
}

func (s *Server) UpsertAiUserConfig(ctx context.Context, in *llmv1.UpsertAiUserConfigReq) (*llmv1.UpsertAiUserConfigResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	return app.UpsertAiUserConfig(ctx, in)
}

func (s *Server) GetAiMemorySettings(ctx context.Context, _ *llmv1.GetAiMemorySettingsReq) (*llmv1.GetAiMemorySettingsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	auto := aiUserMemoryAutoLearnEnabled(ctx, app, userID)
	return &llmv1.GetAiMemorySettingsResp{AutoLearn: auto}, nil
}

func (s *Server) PutAiMemorySettings(ctx context.Context, in *llmv1.PutAiMemorySettingsReq) (*llmv1.PutAiMemorySettingsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	existing := map[string]interface{}{}
	if cur, getErr := app.GetAiUserConfig(ctx, &llmv1.GetAiUserConfigReq{UserId: userID}); getErr == nil && cur != nil {
		existing = llmbiz.DecodePreferencesJSON(cur.GetPreferencesJson())
	}
	prefsJSON := llmbiz.MergeMemoryAutoLearnPref(existing, in.GetAutoLearn())
	if _, rpcErr := app.UpsertAiUserConfig(ctx, &llmv1.UpsertAiUserConfigReq{
		UserId:          userID,
		PreferencesJson: prefsJSON,
	}); rpcErr != nil {
		return nil, rpcErr
	}
	return &llmv1.PutAiMemorySettingsResp{AutoLearn: in.GetAutoLearn()}, nil
}

func (s *Server) ListLlmModels(ctx context.Context, _ *llmv1.ListLlmModelsReq) (*llmv1.ListLlmModelsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	names, err := app.ListModels(ctx)
	if err != nil {
		return nil, err
	}
	return &llmv1.ListLlmModelsResp{Models: names}, nil
}

func (s *Server) ListLlmLocalModelsCatalog(ctx context.Context, _ *llmv1.ListLlmLocalModelsCatalogReq) (*llmv1.ListLlmLocalModelsCatalogResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	catalog, err := app.LocalCatalog()
	if err != nil {
		return nil, err
	}
	items := make([]*llmv1.LlmLocalModelCatalogItem, 0, len(catalog))
	for _, item := range catalog {
		items = append(items, &llmv1.LlmLocalModelCatalogItem{
			Id: item.ID, Name: item.Name, Filename: item.Filename,
			SizeBytes: item.SizeBytes, Sha256: item.Sha256, Description: item.Description,
			ParametersB: item.ParametersB, Recommended: item.Recommended, DownloadPath: item.DownloadPath,
		})
	}
	return &llmv1.ListLlmLocalModelsCatalogResp{Items: items}, nil
}

func aiUserMemoryAutoLearnEnabled(ctx context.Context, app interface {
	GetAiUserConfig(context.Context, *llmv1.GetAiUserConfigReq) (*llmv1.GetAiUserConfigResp, error)
}, userID string) bool {
	if userID == "" {
		return true
	}
	resp, err := app.GetAiUserConfig(ctx, &llmv1.GetAiUserConfigReq{UserId: userID})
	if err != nil || resp == nil {
		return true
	}
	prefs := llmbiz.DecodePreferencesJSON(resp.GetPreferencesJson())
	if v, ok := prefs["memory_auto_learn"]; ok {
		switch t := v.(type) {
		case bool:
			return t
		case string:
			return t != "false" && t != "0"
		case float64:
			return t != 0
		}
	}
	return true
}
