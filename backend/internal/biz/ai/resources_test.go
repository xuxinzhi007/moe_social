package aibiz

import (
	"context"
	"encoding/json"
	"testing"

	aiv1 "backend/api/ai/v1"
	"backend/model"

	"gorm.io/gorm"
)

func TestListPublicAgentsOverridesPayloadAuthor(t *testing.T) {
	store := &publicAgentStoreStub{configs: []model.AiUserConfig{{
		UserID:     42,
		AgentsJSON: `[{"id":"agent-1","is_public":true,"created_by_user_id":"999"}]`,
	}}}
	usecase := NewResourcesUsecase(store)

	response, err := usecase.ListPublicAgents(context.Background(), &aiv1.ListPublicAiAgentsReq{})
	if err != nil {
		t.Fatalf("ListPublicAgents() error = %v", err)
	}
	if len(response.Items) != 1 {
		t.Fatalf("ListPublicAgents() items = %d, want 1", len(response.Items))
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(response.Items[0].PayloadJson), &payload); err != nil {
		t.Fatalf("decode payload: %v", err)
	}
	if payload["created_by_user_id"] != "42" {
		t.Fatalf("created_by_user_id = %v, want 42", payload["created_by_user_id"])
	}
}

type publicAgentStoreStub struct {
	configs []model.AiUserConfig
}

func (s *publicAgentStoreStub) Raw() *gorm.DB { return nil }

func (s *publicAgentStoreStub) WithContext(context.Context) AiStore { return s }

func (s *publicAgentStoreStub) LoadOrCreateConfig(context.Context, uint) (*model.AiUserConfig, error) {
	return nil, nil
}

func (s *publicAgentStoreStub) SaveConfig(context.Context, *model.AiUserConfig) error { return nil }

func (s *publicAgentStoreStub) UpdateConfig(context.Context, uint, func(*model.AiUserConfig) error) (*model.AiUserConfig, error) {
	return nil, nil
}

func (s *publicAgentStoreStub) FindAllConfigs(context.Context) ([]model.AiUserConfig, error) {
	return s.configs, nil
}

func (s *publicAgentStoreStub) GetUserDisplayName(context.Context, uint) string { return "owner" }
