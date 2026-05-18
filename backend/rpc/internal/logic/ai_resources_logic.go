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
		resp.Items = append(resp.Items, &super.AiJsonResourceItem{
			Id:          fmt.Sprint(item["id"]),
			PayloadJson: mustJSON(item),
		})
	}
	return resp, nil
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
	setField(cfg, field, encodeAIJSONArray(items))
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("save AI config failed: %v", err))
	}
	if field == "agents" && !replaced {
		l.notifyAgentCreated(userID, item)
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
	next := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		if fmt.Sprint(item["id"]) != in.Id {
			next = append(next, item)
		}
	}
	setField(cfg, field, encodeAIJSONArray(next))
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("save AI config failed: %v", err))
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

func mustJSON(v interface{}) string {
	raw, _ := json.Marshal(v)
	return string(raw)
}

func (l *AiResourcesLogic) notifyAgentCreated(userID uint, item map[string]interface{}) {
	agentID := fmt.Sprint(item["id"])
	agentName := stringValue(item["name"])
	modelName := stringValue(item["model_name"])
	description := stringValue(item["description"])
	providerProfile := stringValue(item["provider_profile_id"])
	createdAt := parseAgentCreatedAt(item["created_at"])
	userName := l.resolveUserDisplayName(userID)

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		err := utils.SendFeishuAgentCreatedNotification(ctx, utils.FeishuAgentCreatedNotification{
			UserName:        userName,
			UserID:          fmt.Sprint(userID),
			AgentID:         agentID,
			AgentName:       agentName,
			Description:     description,
			ModelName:       modelName,
			ProviderProfile: providerProfile,
			CreatedAt:       createdAt,
		})
		if err != nil {
			l.Errorf("feishu agent-created notification failed: %v", err)
		}
	}()
}

func (l *AiResourcesLogic) resolveUserDisplayName(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.Select("id", "username", "email").First(&user, userID).Error; err == nil {
		if strings.TrimSpace(user.Username) != "" {
			return user.Username
		}
		if strings.TrimSpace(user.Email) != "" {
			return user.Email
		}
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
