package aibiz

import (
	"context"
	"encoding/json"
	"fmt"

	aiv1 "backend/api/ai/v1"

	"gorm.io/gorm"
)

// UpsertOutcome upsert 结果（供 service 层发通知）。
type UpsertOutcome struct {
	Resp     *aiv1.UpsertAiResourceResp
	Replaced bool
	UserID   uint
	Field    string
	Item     map[string]interface{}
}

// DeleteOutcome delete 结果（供 service 层发通知）。
type DeleteOutcome struct {
	Resp        *aiv1.DeleteAiResourceResp
	UserID      uint
	Field       string
	DeletedItem map[string]interface{}
}

// List 列出用户 AI 资源。
func List(ctx context.Context, store AiStore, field string, in *aiv1.ListAiResourceReq) (*aiv1.ListAiResourceResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, err
	}
	var raw string
	switch field {
	case "providers":
		raw = cfg.ProviderProfilesJSON
	case "agents":
		raw = cfg.AgentsJSON
	case "lorebooks":
		raw = cfg.LorebooksJSON
	default:
		return nil, ErrUnknownResourceKind
	}
	items := DecodeJSONArray(raw)
	resp := &aiv1.ListAiResourceResp{Items: make([]*aiv1.AiJsonResourceItem, 0, len(items))}
	for _, item := range items {
		payload, err := mustJSON(item)
		if err != nil {
			return nil, err
		}
		resp.Items = append(resp.Items, &aiv1.AiJsonResourceItem{
			Id:          fmt.Sprint(item["id"]),
			PayloadJson: payload,
		})
	}
	return resp, nil
}

// ListPublicAgents 列出公开 AI 角色。
func ListPublicAgents(ctx context.Context, store AiStore, in *aiv1.ListPublicAiAgentsReq) (*aiv1.ListAiResourceResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	configs, err := store.FindAllConfigs(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPublicAgents, err)
	}

	resp := &aiv1.ListAiResourceResp{Items: make([]*aiv1.AiJsonResourceItem, 0)}
	for _, cfg := range configs {
		if len(resp.Items) >= limit {
			break
		}
		agents := DecodeJSONArray(cfg.AgentsJSON)
		for _, item := range agents {
			if len(resp.Items) >= limit {
				break
			}
			if !AgentIsPublic(item) {
				continue
			}
			if _, ok := item["created_by_user_id"]; !ok {
				item["created_by_user_id"] = fmt.Sprint(cfg.UserID)
			}
			if name := store.GetUserDisplayName(ctx, cfg.UserID); name != "" {
				item["author_name"] = name
			}
			payload, err := mustJSON(item)
			if err != nil {
				return nil, err
			}
			resp.Items = append(resp.Items, &aiv1.AiJsonResourceItem{
				Id:          fmt.Sprint(item["id"]),
				PayloadJson: payload,
			})
		}
	}
	return resp, nil
}

// Upsert 写入或更新 AI 资源。
func Upsert(ctx context.Context, store AiStore, field string, in *aiv1.UpsertAiResourceReq) (*UpsertOutcome, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, err
	}
	item := map[string]interface{}{}
	if err := json.Unmarshal([]byte(in.GetPayloadJson()), &item); err != nil {
		return nil, ErrInvalidPayload
	}
	items := DecodeJSONArray(selectField(cfg, field))
	id := fmt.Sprint(item["id"])
	replaced := false
	for i, current := range items {
		if fmt.Sprint(current["id"]) == id {
			items[i] = item
			replaced = true
			break
		}
	}
	if !replaced {
		items = append(items, item)
	}
	encoded, err := EncodeJSONArray(items)
	if err != nil {
		return nil, err
	}
	setField(cfg, field, encoded)
	if err := store.SaveConfig(ctx, cfg); err != nil {
		return nil, err
	}
	return &UpsertOutcome{
		Resp: &aiv1.UpsertAiResourceResp{
			Item: &aiv1.AiJsonResourceItem{
				Id:          id,
				PayloadJson: in.GetPayloadJson(),
			},
		},
		Replaced: replaced,
		UserID:   userID,
		Field:    field,
		Item:     item,
	}, nil
}

// Delete 删除 AI 资源。
func Delete(ctx context.Context, store AiStore, field string, in *aiv1.DeleteAiResourceReq) (*DeleteOutcome, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	store = store.WithContext(ctx)
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, userID)
	if err != nil {
		return nil, err
	}
	items := DecodeJSONArray(selectField(cfg, field))
	var deletedItem map[string]interface{}
	next := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		if fmt.Sprint(item["id"]) == in.GetId() {
			deletedItem = item
			continue
		}
		next = append(next, item)
	}
	encoded, err := EncodeJSONArray(next)
	if err != nil {
		return nil, err
	}
	setField(cfg, field, encoded)
	if err := store.SaveConfig(ctx, cfg); err != nil {
		return nil, err
	}
	return &DeleteOutcome{
		Resp:        &aiv1.DeleteAiResourceResp{Ok: true},
		UserID:      userID,
		Field:       field,
		DeletedItem: deletedItem,
	}, nil
}
