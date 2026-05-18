package ai

import (
	"backend/api/internal/types"
)

func (l *ResourceLogic) ListAgents(userID uint) (*types.AiAgentsResp, error) {
	items, baseResp := l.list(userID, "agents")
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) UpsertAgent(userID uint, item map[string]interface{}) (*types.AiAgentsResp, error) {
	items, baseResp := l.upsert(userID, "agents", item)
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) DeleteAgent(userID uint, id string) (*types.AiAgentsResp, error) {
	items, baseResp := l.delete(userID, "agents", id)
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}
