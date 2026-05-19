package logic

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AiResourcesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAiResourcesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AiResourcesLogic {
	return &AiResourcesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AiResourcesLogic) list(field string, in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("read AI config failed: %v", err))
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
		return nil, errorx.Internal("unknown AI resource kind")
	}
	items := decodeAIJSONArray(raw)
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

func (l *AiResourcesLogic) listPublicAgents(in *super.ListPublicAiAgentsReq) (*super.ListAiResourceResp, error) {
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	var configs []model.AiUserConfig
	if err := l.svcCtx.DB.Find(&configs).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("list public agents failed: %v", err))
	}

	resp := &super.ListAiResourceResp{Items: make([]*super.AiJsonResourceItem, 0)}
	for _, cfg := range configs {
		if len(resp.Items) >= limit {
			break
		}
		agents := decodeAIJSONArray(cfg.AgentsJSON)
		for _, item := range agents {
			if len(resp.Items) >= limit {
				break
			}
			if !agentIsPublic(item) {
				continue
			}
			if _, ok := item["created_by_user_id"]; !ok {
				item["created_by_user_id"] = fmt.Sprint(cfg.UserID)
			}
			if name := l.resolveUserDisplayName(cfg.UserID); name != "" {
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

func agentIsPublic(item map[string]interface{}) bool {
	raw, ok := item["is_public"]
	if !ok {
		return false
	}
	switch v := raw.(type) {
	case bool:
		return v
	case string:
		s := strings.TrimSpace(strings.ToLower(v))
		return s == "true" || s == "1" || s == "yes"
	case float64:
		return v != 0
	case int:
		return v != 0
	case int64:
		return v != 0
	default:
		return false
	}
}

func (l *AiResourcesLogic) upsert(field string, in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("read AI config failed: %v", err))
	}
	item := map[string]interface{}{}
	if err := json.Unmarshal([]byte(in.PayloadJson), &item); err != nil {
		return nil, errorx.InvalidArgument("invalid payload_json")
	}
	items := decodeAIJSONArray(selectField(cfg, field))
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
	encoded, err := encodeAIJSONArray(items)
	if err != nil {
		return nil, err
	}
	setField(cfg, field, encoded)
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("save AI config failed: %v", err))
	}
	if field == "agents" {
		if !replaced {
			l.notifyAgentEvent(userID, item, utils.FeishuAgentCreated)
		} else {
			l.notifyAgentEvent(userID, item, utils.FeishuAgentUpdated)
		}
	}
	return &super.UpsertAiResourceResp{
		Item: &super.AiJsonResourceItem{
			Id:          id,
			PayloadJson: in.PayloadJson,
		},
	}, nil
}

func (l *AiResourcesLogic) delete(field string, in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("read AI config failed: %v", err))
	}
	items := decodeAIJSONArray(selectField(cfg, field))
	var deletedItem map[string]interface{}
	next := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		if fmt.Sprint(item["id"]) == in.Id {
			deletedItem = item
			continue
		}
		next = append(next, item)
	}
	encoded, err := encodeAIJSONArray(next)
	if err != nil {
		return nil, err
	}
	setField(cfg, field, encoded)
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("save AI config failed: %v", err))
	}
	if field == "agents" && deletedItem != nil {
		l.notifyAgentEvent(userID, deletedItem, utils.FeishuAgentDeleted)
	}
	return &super.DeleteAiResourceResp{Ok: true}, nil
}

func selectField(cfg *model.AiUserConfig, field string) string {
	switch field {
	case "providers":
		return cfg.ProviderProfilesJSON
	case "agents":
		return cfg.AgentsJSON
	case "lorebooks":
		return cfg.LorebooksJSON
	default:
		return "[]"
	}
}

func setField(cfg *model.AiUserConfig, field, value string) {
	switch field {
	case "providers":
		cfg.ProviderProfilesJSON = value
	case "agents":
		cfg.AgentsJSON = value
	case "lorebooks":
		cfg.LorebooksJSON = value
	}
}

func mustJSON(v interface{}) (string, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return "", errorx.Internal(fmt.Sprintf("encode AI resource item failed: %v", err))
	}
	return string(raw), nil
}

func (l *AiResourcesLogic) notifyAgentEvent(userID uint, item map[string]interface{}, action utils.FeishuAgentAction) {
	agentID := fmt.Sprint(item["id"])
	agentName := stringValue(item["name"])
	modelName := stringValue(item["model_name"])
	description := stringValue(item["description"])
	providerProfile := stringValue(item["provider_profile_id"])
	eventAt := parseAgentCreatedAt(item["created_at"])
	userName := l.resolveUserDisplayName(userID)
	feishuEmail := l.resolveUserFeishuEmail(userID)

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		err := utils.SendFeishuAgentEventNotification(ctx, utils.FeishuAgentEvent{
			Action:          action,
			UserName:        userName,
			UserID:          fmt.Sprint(userID),
			AgentID:         agentID,
			AgentName:       agentName,
			Description:     description,
			ModelName:       modelName,
			ProviderProfile: providerProfile,
			EventAt:         eventAt,
		}, feishuEmail)
		if err != nil {
			l.Errorf("feishu agent %s notification failed: %v", action, err)
		}
	}()
}

func (l *AiResourcesLogic) resolveUserFeishuEmail(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.Select("feishu_email").First(&user, userID).Error; err == nil {
		return strings.TrimSpace(user.FeishuEmail)
	}
	return ""
}

func (l *AiResourcesLogic) resolveUserDisplayName(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.Select("id", "username", "email", "feishu_name").First(&user, userID).Error; err != nil {
		return fmt.Sprintf("user#%d", userID)
	}
	username := strings.TrimSpace(user.Username)
	feishuName := strings.TrimSpace(user.FeishuName)
	if username != "" && feishuName != "" && username != feishuName {
		return username + "（飞书：" + feishuName + "）"
	}
	if username != "" {
		return username
	}
	if feishuName != "" {
		return feishuName
	}
	if strings.TrimSpace(user.Email) != "" {
		return user.Email
	}
	return fmt.Sprintf("user#%d", userID)
}

func parseAgentCreatedAt(raw interface{}) time.Time {
	switch v := raw.(type) {
	case nil:
		return time.Now()
	case int64:
		return time.UnixMilli(v)
	case int32:
		return time.UnixMilli(int64(v))
	case int:
		return time.UnixMilli(int64(v))
	case float64:
		return time.UnixMilli(int64(v))
	case float32:
		return time.UnixMilli(int64(v))
	case json.Number:
		if n, err := v.Int64(); err == nil {
			return time.UnixMilli(n)
		}
	case string:
		if n, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64); err == nil {
			return time.UnixMilli(n)
		}
	}
	return time.Now()
}

func stringValue(raw interface{}) string {
	if raw == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(raw))
}
