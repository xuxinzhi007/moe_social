package conf

import "testing"

func TestModelManagementTypedYAML(t *testing.T) {
	loadBody(t, `llm_inference:
  memory_model: default:latest
  model_management:
    user_quota: 2
    global_quota: 7
    write_concurrency: 2
    model_sync_timeout_seconds: 80
    allowed_base_models: [one:latest, two:latest]
`)
	actual := InferenceModelManagement()
	if actual.UserQuota != 2 || actual.GlobalQuota != 7 || actual.WriteConcurrency != 2 || actual.ModelSyncTimeoutSeconds != 80 || len(actual.AllowedBaseModels) != 2 || actual.AllowedBaseModels[1] != "two:latest" {
		t.Fatalf("typed config: %+v", actual)
	}
}

func TestModelManagementDefaultsAndExplicitLimits(t *testing.T) {
	defaults := NormalizeModelManagement(ModelManagement{}, "base:latest")
	if defaults.UserQuota != 3 || defaults.GlobalQuota != 12 || defaults.WriteConcurrency != 1 || defaults.ModelSyncTimeoutSeconds != 120 || len(defaults.AllowedBaseModels) != 1 || defaults.AllowedBaseModels[0] != "base:latest" {
		t.Fatalf("defaults: %+v", defaults)
	}
	input := ModelManagement{UserQuota: 2, GlobalQuota: 9, WriteConcurrency: 2, ModelSyncTimeoutSeconds: 90, AllowedBaseModels: []string{"one", "two"}}
	actual := NormalizeModelManagement(input, "default")
	if actual.UserQuota != 2 || actual.GlobalQuota != 9 || actual.WriteConcurrency != 2 || actual.ModelSyncTimeoutSeconds != 90 || len(actual.AllowedBaseModels) != 2 {
		t.Fatal(actual)
	}
	actual.AllowedBaseModels[0] = "changed"
	if input.AllowedBaseModels[0] != "one" {
		t.Fatal("shared mutable allowlist")
	}
	if c := NormalizeModelManagement(ModelManagement{}, ""); len(c.AllowedBaseModels) != 0 {
		t.Fatal("empty config must not allow models")
	}
}
