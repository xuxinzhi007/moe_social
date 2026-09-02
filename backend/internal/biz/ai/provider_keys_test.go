package aibiz

import (
	"context"
	"encoding/json"
	"reflect"
	"strings"
	"sync"
	"testing"

	llmv1 "backend/api/llm/v1"
	"backend/model"

	"gorm.io/gorm"
)

func TestProviderAPIKeysEncryptionRoundTrip(t *testing.T) {
	t.Setenv(providerKeysSecretEnv, "provider-key-test-secret")

	const apiKey = "sk-live-provider-key"
	encoded, err := encodeProviderAPIKeys(map[string]string{
		"profile-1": "Bearer " + apiKey,
		"profile-2": "  sk-second  ",
		"":          "ignored",
	})
	if err != nil {
		t.Fatalf("encodeProviderAPIKeys() error = %v", err)
	}
	if strings.Contains(encoded, apiKey) {
		t.Fatalf("ciphertext contains plaintext API key")
	}

	got, err := decodeProviderAPIKeys(encoded)
	if err != nil {
		t.Fatalf("decodeProviderAPIKeys() error = %v", err)
	}
	want := map[string]string{
		"profile-1": apiKey,
		"profile-2": "sk-second",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("decoded keys = %#v, want %#v", got, want)
	}
}

func TestUpsertAiUserConfigProviderKeyLifecycle(t *testing.T) {
	t.Setenv(providerKeysSecretEnv, "provider-key-test-secret")

	store := &providerKeyConfigStoreStub{
		config: &model.AiUserConfig{
			UserID:               42,
			ProviderProfilesJSON: `[{"id":"profile-1","name":"OpenAI"}]`,
			PreferencesJSON:      "{}",
		},
	}

	_, err := UpsertAiUserConfig(context.Background(), store, &llmv1.UpsertAiUserConfigReq{
		UserId:                  "42",
		ProviderApiKeyProfileId: "profile-1",
		ProviderApiKey:          "sk-first",
		HasProviderApiKey:       true,
	})
	if err != nil {
		t.Fatalf("initial provider key upsert error = %v", err)
	}
	assertStoredProviderKeys(t, store.config, map[string]string{
		"profile-1": "sk-first",
	})
	if strings.Contains(store.config.ProviderApiKeysEncrypted, "sk-first") {
		t.Fatalf("stored provider key ciphertext contains plaintext")
	}
	if strings.Contains(store.config.ProviderProfilesJSON, "sk-first") {
		t.Fatalf("provider metadata JSON contains API key")
	}

	_, err = UpsertAiUserConfig(context.Background(), store, &llmv1.UpsertAiUserConfigReq{
		UserId:                  "42",
		ProviderApiKeyProfileId: "profile-1",
		ProviderApiKey:          "Bearer sk-updated",
		HasProviderApiKey:       true,
	})
	if err != nil {
		t.Fatalf("provider key update error = %v", err)
	}
	assertStoredProviderKeys(t, store.config, map[string]string{
		"profile-1": "sk-updated",
	})

	_, err = UpsertAiUserConfig(context.Background(), store, &llmv1.UpsertAiUserConfigReq{
		UserId:                  "42",
		ProviderApiKeyProfileId: "profile-1",
		HasProviderApiKey:       true,
	})
	if err != nil {
		t.Fatalf("provider key delete error = %v", err)
	}
	assertStoredProviderKeys(t, store.config, map[string]string{})

	rawConfig, err := json.Marshal(store.config)
	if err != nil {
		t.Fatalf("marshal AI config: %v", err)
	}
	if strings.Contains(string(rawConfig), "sk-updated") {
		t.Fatalf("serialized AI config contains API key")
	}
}

func TestUpsertAiUserConfigPreservesConcurrentProviderKeys(t *testing.T) {
	t.Setenv(providerKeysSecretEnv, "provider-key-test-secret")

	store := &providerKeyConfigStoreStub{
		config: &model.AiUserConfig{UserID: 42, PreferencesJSON: "{}"},
	}
	requests := []*llmv1.UpsertAiUserConfigReq{
		{UserId: "42", ProviderApiKeyProfileId: "profile-1", ProviderApiKey: "sk-first", HasProviderApiKey: true},
		{UserId: "42", ProviderApiKeyProfileId: "profile-2", ProviderApiKey: "sk-second", HasProviderApiKey: true},
	}
	errCh := make(chan error, len(requests))
	var waitGroup sync.WaitGroup
	for _, request := range requests {
		waitGroup.Add(1)
		go func(request *llmv1.UpsertAiUserConfigReq) {
			defer waitGroup.Done()
			_, err := UpsertAiUserConfig(context.Background(), store, request)
			errCh <- err
		}(request)
	}
	waitGroup.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			t.Fatalf("concurrent provider key upsert error = %v", err)
		}
	}
	assertStoredProviderKeys(t, store.config, map[string]string{
		"profile-1": "sk-first",
		"profile-2": "sk-second",
	})
}

func assertStoredProviderKeys(
	t *testing.T,
	config *model.AiUserConfig,
	want map[string]string,
) {
	t.Helper()

	got, err := decodeProviderAPIKeys(config.ProviderApiKeysEncrypted)
	if err != nil {
		t.Fatalf("decode stored provider keys: %v", err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("stored provider keys = %#v, want %#v", got, want)
	}
}

type providerKeyConfigStoreStub struct {
	mu     sync.Mutex
	config *model.AiUserConfig
}

func (s *providerKeyConfigStoreStub) Raw() *gorm.DB {
	return nil
}

func (s *providerKeyConfigStoreStub) WithContext(context.Context) AiStore {
	return s
}

func (s *providerKeyConfigStoreStub) LoadOrCreateConfig(
	context.Context,
	uint,
) (*model.AiUserConfig, error) {
	return s.config, nil
}

func (s *providerKeyConfigStoreStub) SaveConfig(
	_ context.Context,
	config *model.AiUserConfig,
) error {
	s.config = config
	return nil
}

func (s *providerKeyConfigStoreStub) UpdateConfig(
	_ context.Context,
	_ uint,
	mutate func(*model.AiUserConfig) error,
) (*model.AiUserConfig, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := mutate(s.config); err != nil {
		return nil, err
	}
	return s.config, nil
}

func (s *providerKeyConfigStoreStub) FindAllConfigs(
	context.Context,
) ([]model.AiUserConfig, error) {
	return nil, nil
}

func (s *providerKeyConfigStoreStub) GetUserDisplayName(
	context.Context,
	uint,
) string {
	return ""
}
