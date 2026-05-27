package aibiz

import (
	"context"
	"encoding/json"
	"fmt"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// UpsertOutcome upsert 结果（供 service 层发通知）。
type UpsertOutcome struct {
	Resp     *super.UpsertAiResourceResp
	Replaced bool
	UserID   uint
	Field    string
	Item     map[string]interface{}
}

// DeleteOutcome delete 结果（供 service 层发通知）。
type DeleteOutcome struct {
	Resp        *super.DeleteAiResourceResp
	UserID      uint
	Field       string
	DeletedItem map[string]interface{}
}

// List 列出用户 AI 资源。
func List(ctx context.Context, db *gorm.DB, field string, in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := LoadOrCreateConfig(db.WithContext(ctx), userID)
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
	resp := &super.ListAiResourceResp{Items: make([]*super.AiJsonResourceItem, 0, len(items))}
	for _, item := range items {
		payload, err := mustJSON(item)
		if err != nil {
			return nil, err
		}
		resp.Items = append(resp.Items, &super.AiJsonResourceItem{
			Id:          fmt.Sprint(item["id"]),
			PayloadJson: payload,
		})
	}
	return resp, nil
}

// ListPublicAgents 列出公开 AI 角色。
func ListPublicAgents(ctx context.Context, db *gorm.DB, in *super.ListPublicAiAgentsReq) (*super.ListAiResourceResp, error) {
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	var configs []model.AiUserConfig
	if err := db.WithContext(ctx).Find(&configs).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListPublicAgents, err)
	}

	resp := &super.ListAiResourceResp{Items: make([]*super.AiJsonResourceItem, 0)}
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
			if name := ResolveUserDisplayName(db, cfg.UserID); name != "" {
				item["author_name"] = name
			}
			payload, err := mustJSON(item)
			if err != nil {
				return nil, err
			}
			resp.Items = append(resp.Items, &super.AiJsonResourceItem{
				Id:          fmt.Sprint(item["id"]),
				PayloadJson: payload,
			})
		}
	}
	return resp, nil
}

// Upsert 写入或更新 AI 资源。
func Upsert(ctx context.Context, db *gorm.DB, field string, in *super.UpsertAiResourceReq) (*UpsertOutcome, error) {
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := LoadOrCreateConfig(db.WithContext(ctx), userID)
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
	if err := db.WithContext(ctx).Save(cfg).Error; err != nil {
		return nil, err
	}
	return &UpsertOutcome{
		Resp: &super.UpsertAiResourceResp{
			Item: &super.AiJsonResourceItem{
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
func Delete(ctx context.Context, db *gorm.DB, field string, in *super.DeleteAiResourceReq) (*DeleteOutcome, error) {
	userID, err := ParseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	cfg, err := LoadOrCreateConfig(db.WithContext(ctx), userID)
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
	if err := db.WithContext(ctx).Save(cfg).Error; err != nil {
		return nil, err
	}
	return &DeleteOutcome{
		Resp:        &super.DeleteAiResourceResp{Ok: true},
		UserID:      userID,
		Field:       field,
		DeletedItem: deletedItem,
	}, nil
}
