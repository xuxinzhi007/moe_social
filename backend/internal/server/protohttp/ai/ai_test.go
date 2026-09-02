package aihttp

import (
	"context"
	"testing"

	aiv1 "backend/api/ai/v1"
	aibiz "backend/internal/biz/ai"
	aiapp "backend/internal/service/ai"
	"backend/model"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	"gorm.io/gorm"
)

type actorStoreStub struct {
	loadedUserID uint
}

func (s *actorStoreStub) Raw() *gorm.DB { return nil }

func (s *actorStoreStub) WithContext(context.Context) aibiz.AiStore { return s }

func (s *actorStoreStub) LoadOrCreateConfig(_ context.Context, userID uint) (*model.AiUserConfig, error) {
	s.loadedUserID = userID
	return &model.AiUserConfig{
		ProviderProfilesJSON: "[]",
		AgentsJSON:           "[]",
		LorebooksJSON:        "[]",
	}, nil
}

func (s *actorStoreStub) SaveConfig(context.Context, *model.AiUserConfig) error { return nil }

func (s *actorStoreStub) UpdateConfig(
	context.Context,
	uint,
	func(*model.AiUserConfig) error,
) (*model.AiUserConfig, error) {
	return nil, nil
}

func (s *actorStoreStub) FindAllConfigs(context.Context) ([]model.AiUserConfig, error) {
	return nil, nil
}

func (s *actorStoreStub) GetUserDisplayName(context.Context, uint) string { return "" }

func TestListAiProvidersUsesActorUserID(t *testing.T) {
	store := &actorStoreStub{}
	server := New(aiapp.New(aibiz.NewResourcesUsecase(store)))
	in := &aiv1.ListAiResourceReq{UserId: "999"}
	ctx := context.WithValue(context.Background(), "userId", "42")

	if _, err := server.ListAiProviders(ctx, in); err != nil {
		t.Fatalf("ListAiProviders() error = %v", err)
	}
	if in.UserId != "42" {
		t.Fatalf("request user_id = %q, want actor user ID 42", in.UserId)
	}
	if store.loadedUserID != 42 {
		t.Fatalf("loaded user ID = %d, want 42", store.loadedUserID)
	}
}

func TestListAiProvidersRequiresActor(t *testing.T) {
	server := New(nil)

	_, err := server.ListAiProviders(context.Background(), &aiv1.ListAiResourceReq{UserId: "999"})
	if !kerrors.IsUnauthorized(err) {
		t.Fatalf("ListAiProviders() error = %v, want Unauthorized", err)
	}
}

func TestListPublicAiAgentsDoesNotRequireActor(t *testing.T) {
	store := &actorStoreStub{}
	server := New(aiapp.New(aibiz.NewResourcesUsecase(store)))

	if _, err := server.ListPublicAiAgents(context.Background(), &aiv1.ListPublicAiAgentsReq{}); err != nil {
		t.Fatalf("ListPublicAiAgents() error = %v", err)
	}
}
