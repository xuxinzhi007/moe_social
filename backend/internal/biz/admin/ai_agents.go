package adminbiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	adminv1 "backend/api/admin/v1"
	aibiz "backend/internal/biz/ai"
	aidata "backend/internal/data/ai"
	"backend/model"

	"gorm.io/gorm"
)

// ListAiAgents Admin 公开 AI 角色列表。
func ListAiAgents(ctx context.Context, db *gorm.DB, in *adminv1.AdminListAiAgentsReq) (*adminv1.AdminListAiAgentsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	kw := strings.ToLower(strings.TrimSpace(in.GetKeyword()))

	var configs []model.AiUserConfig
	if err := db.WithContext(ctx).Find(&configs).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", aibiz.ErrAdminListAgents, err)
	}

	type agentRow struct {
		id        string
		ownerID   uint
		ownerName string
		payload   string
	}
	all := make([]agentRow, 0)
	for _, cfg := range configs {
		ownerName := resolveAdminOwnerName(db, cfg.UserID)
		agents := aibiz.DecodeJSONArray(cfg.AgentsJSON)
		for _, item := range agents {
			if !aibiz.AgentIsPublic(item) {
				continue
			}
			id := fmt.Sprint(item["id"])
			name := strings.ToLower(fmt.Sprint(item["name"]))
			if kw != "" && !strings.Contains(id, kw) && !strings.Contains(name, kw) && !strings.Contains(ownerName, kw) {
				continue
			}
			if _, ok := item["created_by_user_id"]; !ok {
				item["created_by_user_id"] = fmt.Sprint(cfg.UserID)
			}
			if ownerName != "" {
				item["author_name"] = ownerName
			}
			payload, err := json.Marshal(item)
			if err != nil {
				return nil, aibiz.ErrEncodeResource
			}
			all = append(all, agentRow{
				id:        id,
				ownerID:   cfg.UserID,
				ownerName: ownerName,
				payload:   string(payload),
			})
		}
	}

	total := int32(len(all))
	start := int((page - 1) * pageSize)
	if start >= len(all) {
		return &adminv1.AdminListAiAgentsResp{Items: []*adminv1.AdminAiAgentItem{}, Total: total}, nil
	}
	end := start + int(pageSize)
	if end > len(all) {
		end = len(all)
	}
	slice := all[start:end]
	items := make([]*adminv1.AdminAiAgentItem, len(slice))
	for i, row := range slice {
		items[i] = &adminv1.AdminAiAgentItem{
			Id:          row.id,
			OwnerUserId: fmt.Sprint(row.ownerID),
			OwnerName:   row.ownerName,
			PayloadJson: row.payload,
		}
	}
	return &adminv1.AdminListAiAgentsResp{Items: items, Total: total}, nil
}

// DeleteAiAgent Admin 删除公开 AI 角色。
func DeleteAiAgent(ctx context.Context, db *gorm.DB, in *adminv1.AdminDeleteAiAgentReq) (*adminv1.AdminDeleteAiAgentResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID := strings.TrimSpace(in.GetUserId())
	agentID := strings.TrimSpace(in.GetAgentId())
	if userID == "" || agentID == "" {
		return nil, aibiz.ErrEmptyUserID
	}
	if err := deleteAiAgentResource(ctx, aidata.NewStore(db), userID, agentID); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteAiAgentResp{}, nil
}

func deleteAiAgentResource(ctx context.Context, store aibiz.AiStore, userID, agentID string) error {
	store = store.WithContext(ctx)
	uid, err := aibiz.ParseUserID(userID)
	if err != nil {
		return err
	}
	cfg, err := store.LoadOrCreateConfig(ctx, uid)
	if err != nil {
		return err
	}
	items := aibiz.DecodeJSONArray(cfg.AgentsJSON)
	next := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		if fmt.Sprint(item["id"]) == agentID {
			continue
		}
		next = append(next, item)
	}
	encoded, err := aibiz.EncodeJSONArray(next)
	if err != nil {
		return err
	}
	cfg.AgentsJSON = encoded
	return store.SaveConfig(ctx, cfg)
}

func resolveAdminOwnerName(db *gorm.DB, userID uint) string {
	var user model.User
	if err := db.First(&user, userID).Error; err != nil {
		return ""
	}
	if user.Username != "" {
		return user.Username
	}
	return user.Email
}
