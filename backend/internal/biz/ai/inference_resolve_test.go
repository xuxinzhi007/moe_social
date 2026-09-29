package aibiz

import (
	"context"
	"testing"

	"backend/model"
)

func TestResolveActiveInferenceUsesSavedProvider(t *testing.T) {
	t.Setenv(providerKeysSecretEnv, "provider-key-test-secret")
	encoded, err := encodeProviderAPIKeys(map[string]string{"profile-1": "sk-saved"})
	if err != nil {
		t.Fatalf("encodeProviderAPIKeys() error = %v", err)
	}
	store := &providerKeyConfigStoreStub{
		config: &model.AiUserConfig{
			UserID: 7,
			ProviderProfilesJSON: `[{
				"id":"profile-1",
				"provider_type":"openai_compatible",
				"base_url":"https://api.example.com/v1",
				"default_model":"demo-model"
			}]`,
			PreferencesJSON:          `{"last_selected_provider_id":"profile-1"}`,
			ProviderApiKeysEncrypted: encoded,
		},
	}

	got, err := ResolveActiveInference(context.Background(), store, 7)
	if err != nil {
		t.Fatalf("ResolveActiveInference() error = %v", err)
	}
	if got == nil {
		t.Fatal("ResolveActiveInference() config = nil, want saved provider")
	}
	if got.BaseURL != "https://api.example.com/v1" || got.DefaultModel != "demo-model" || got.APIKey != "sk-saved" {
		t.Fatalf("ResolveActiveInference() = %+v", got)
	}
}

func TestResolveActiveInferenceBuiltinUsesServerDefault(t *testing.T) {
	store := &providerKeyConfigStoreStub{
		config: &model.AiUserConfig{
			UserID:          7,
			PreferencesJSON: `{"last_selected_provider_id":"builtin_backend_ollama"}`,
		},
	}
	got, err := ResolveActiveInference(context.Background(), store, 7)
	if err != nil {
		t.Fatalf("ResolveActiveInference() error = %v", err)
	}
	if got != nil {
		t.Fatalf("ResolveActiveInference() = %+v, want nil server default", got)
	}
}

func TestResolveActiveInferenceRejectsIncompleteProvider(t *testing.T) {
	store := &providerKeyConfigStoreStub{
		config: &model.AiUserConfig{
			UserID:               7,
			ProviderProfilesJSON: `[{"id":"profile-1","base_url":"https://api.example.com/v1"}]`,
			PreferencesJSON:      `{"last_selected_provider_id":"profile-1"}`,
		},
	}
	_, err := ResolveActiveInference(context.Background(), store, 7)
	if err != ErrActiveProviderUnavailable {
		t.Fatalf("ResolveActiveInference() error = %v, want ErrActiveProviderUnavailable", err)
	}
}
