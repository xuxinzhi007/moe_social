package aibiz

import (
	"context"
	"testing"

	"backend/model"
	"backend/pkg/llminference"
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

func TestResolveProfileInferenceUsesBoundProvider(t *testing.T) {
	t.Setenv(providerKeysSecretEnv, "provider-key-test-secret")
	encoded, err := encodeProviderAPIKeys(map[string]string{"profile-2": "sk-bound"})
	if err != nil {
		t.Fatalf("encodeProviderAPIKeys() error = %v", err)
	}
	cfg := &model.AiUserConfig{
		ProviderProfilesJSON: `[{
			"id":"profile-2",
			"provider_type":"openai_compatible",
			"base_url":"https://bound.example/v1",
			"default_model":"bound-model"
		}]`,
		PreferencesJSON:          `{"last_selected_provider_id":"profile-1"}`,
		ProviderApiKeysEncrypted: encoded,
	}
	got, err := ResolveProfileInference(cfg, "profile-2")
	if err != nil {
		t.Fatalf("ResolveProfileInference() error = %v", err)
	}
	if got == nil || got.BaseURL != "https://bound.example/v1" || got.APIKey != "sk-bound" {
		t.Fatalf("ResolveProfileInference() = %+v", got)
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

func TestApplyBuiltinChatModelUsesSavedOllamaModel(t *testing.T) {
	server := llminference.Config{
		BaseURL:      "http://127.0.0.1:11434",
		APIStyle:     llminference.APIOllama,
		DefaultModel: "qwen2.5:3b-instruct",
	}
	cfg := &model.AiUserConfig{
		PreferencesJSON: `{"last_selected_provider_id":"builtin_backend_ollama","builtin_chat_model":"qwen3.5:9b"}`,
	}
	got := applyBuiltinChatModel(cfg, server)
	if got == nil || got.DefaultModel != "qwen3.5:9b" || got.BaseURL != server.BaseURL {
		t.Fatalf("applyBuiltinChatModel() = %+v", got)
	}
	if server.DefaultModel != "qwen2.5:3b-instruct" {
		t.Fatalf("server default model changed to %s", server.DefaultModel)
	}
	if applyBuiltinChatModel(&model.AiUserConfig{PreferencesJSON: `{}`}, server) != nil {
		t.Fatal("applyBuiltinChatModel() without a saved model = non-nil")
	}
	if applyBuiltinChatModel(cfg, llminference.Config{}) != nil {
		t.Fatal("applyBuiltinChatModel() with an unready server = non-nil")
	}
	bad := &model.AiUserConfig{PreferencesJSON: `{"builtin_chat_model":"../secret"}`}
	if applyBuiltinChatModel(bad, server) != nil {
		t.Fatal("applyBuiltinChatModel() accepted an unsafe model name")
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
