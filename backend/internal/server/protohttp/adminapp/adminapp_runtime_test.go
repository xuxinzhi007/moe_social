package adminapphttp

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	adminv1 "backend/api/admin/v1"
	adminapp "backend/internal/service/admin"
	"backend/pkg/conf"
)

func TestRuntimeConfigRawFieldsAndRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.yaml")
	body := "api:\n  public_base_url: 'https://old.example.test'\n" +
		"app_client:\n  public_api_base_url: ''\n" +
		"image:\n  public_base_url: ''\n  local_dir: ''\n  max_bytes: 0\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(conf.ResetForTest)
	if _, err := conf.LoadFile(path); err != nil {
		t.Fatal(err)
	}
	runtime := &RuntimeState{
		ClientPublicAPIBaseURL: "https://old.example.test",
		ImagePublicBaseURL:     "https://old.example.test",
		ImageLocalDir:          "/fragment/images",
		ImageMaxBytes:          4096,
	}
	before := *runtime
	s := New(&adminapp.AppService{}, nil, WithDeps(Deps{
		Runtime:     runtime,
		RecordAudit: func(context.Context, string, string, string, string) {},
	}))
	ctx := context.WithValue(context.Background(), "admin_id", uint(1))
	view, err := s.AdminGetRuntimeConfig(ctx, &adminv1.AdminGetRuntimeConfigReq{})
	if err != nil {
		t.Fatal(err)
	}
	if view.PublicApiBaseUrl != "" || view.ImagePublicBaseUrl != "" || view.ImageLocalDir != "" || view.ImageMaxBytes != 0 || !view.RequiresRestart {
		t.Fatal("editable fields must contain raw values, never startup fallbacks")
	}
	for _, in := range []*adminv1.AdminUpdateRuntimeConfigReq{
		{UpdateApiPublicBaseUrl: true, ApiPublicBaseUrl: "https://new.example.test/"},
		{UpdatePublicApiBaseUrl: true, PublicApiBaseUrl: "https://client.example.test", UpdateImagePublicBaseUrl: true, ImagePublicBaseUrl: "https://images.example.test"},
		{UpdatePublicApiBaseUrl: true, PublicApiBaseUrl: "", UpdateImagePublicBaseUrl: true, ImagePublicBaseUrl: ""},
	} {
		out, err := s.AdminUpdateRuntimeConfig(ctx, in)
		if err != nil {
			t.Fatal(err)
		}
		if !out.RequiresRestart || *runtime != before {
			t.Fatal("runtime consumers must retain a consistent snapshot until restart")
		}
	}
	view, err = s.AdminGetRuntimeConfig(ctx, &adminv1.AdminGetRuntimeConfigReq{})
	if err != nil {
		t.Fatal(err)
	}
	if view.ApiPublicBaseUrl != "https://new.example.test" || view.PublicApiBaseUrl != "" || view.ImagePublicBaseUrl != "" {
		t.Fatal("saving and clearing overrides must not duplicate derived URLs")
	}
	if conf.ImagePublicBaseURL() != "https://new.example.test" || conf.ClientPublicBaseURL() != "https://new.example.test" {
		t.Fatal("reloaded configuration must derive both URLs from the new API root")
	}
}
