package ai

import (
	"backend/api/internal/types"
)

func (l *ResourceLogic) ListProviders(userID uint) (*types.AiProviderProfilesResp, error) {
	items, baseResp := l.list(userID, "providers")
	return &types.AiProviderProfilesResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) UpsertProvider(userID uint, item map[string]interface{}) (*types.AiProviderProfilesResp, error) {
	items, baseResp := l.upsert(userID, "providers", item)
	return &types.AiProviderProfilesResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) DeleteProvider(userID uint, id string) (*types.AiProviderProfilesResp, error) {
	items, baseResp := l.delete(userID, "providers", id)
	return &types.AiProviderProfilesResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}
