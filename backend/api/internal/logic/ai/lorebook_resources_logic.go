package ai

import (
	"backend/api/internal/types"
)

func (l *ResourceLogic) ListLorebooks(userID uint) (*types.AiLorebooksResp, error) {
	items, baseResp := l.list(userID, "lorebooks")
	return &types.AiLorebooksResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) UpsertLorebook(
	userID uint,
	item map[string]interface{},
	entries []map[string]interface{},
) (*types.AiLorebooksResp, error) {
	if entries != nil {
		item["entries"] = entries
	}
	items, baseResp := l.upsert(userID, "lorebooks", item)
	return &types.AiLorebooksResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) DeleteLorebook(userID uint, id string) (*types.AiLorebooksResp, error) {
	items, baseResp := l.delete(userID, "lorebooks", id)
	return &types.AiLorebooksResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}
