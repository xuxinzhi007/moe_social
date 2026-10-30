package mediabiz

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestDrawRequestRejectsOversizedImage(t *testing.T) {
	in := DrawRequest{Prompt: "a photo", Width: 1024, Height: 768}.normalized(ComfyConfig{})
	if err := in.validate(); err != ErrBadDrawSize {
		t.Fatalf("validate = %v", err)
	}
	in = DrawRequest{Prompt: "  a photo  "}.normalized(ComfyConfig{})
	if err := in.validate(); err != nil {
		t.Fatal(err)
	}
	if in.Prompt != "a photo" || in.Width != 512 || in.Height != 768 || in.Steps != 25 || in.CFG != 5 {
		t.Fatalf("defaults = %+v", in)
	}
	if in.Checkpoint != defaultComfyCheckpoint {
		t.Fatalf("checkpoint = %s", in.Checkpoint)
	}
}

func TestGenerateAndStoreUsesComfyThenGenFolder(t *testing.T) {
	var gotCheckpoint string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/object_info/CheckpointLoaderSimple":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"CheckpointLoaderSimple": map[string]any{
					"input": map[string]any{
						"required": map[string]any{
							"ckpt_name": []any{[]string{"Realistic_Vision_V5.1_fp16-no-ema.safetensors", "meinamix_v12Final.safetensors"}},
						},
					},
				},
			})
		case r.URL.Path == "/prompt" && r.Method == http.MethodPost:
			var body struct {
				Prompt map[string]struct {
					Inputs map[string]any `json:"inputs"`
				} `json:"prompt"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Fatal(err)
			}
			gotCheckpoint, _ = body.Prompt["4"].Inputs["ckpt_name"].(string)
			clip, _ := body.Prompt["10"].Inputs["clip"].([]any)
			if len(clip) != 2 || clip[0] != "4" || clip[1] != float64(1) {
				t.Fatalf("clip link = %#v", clip)
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"prompt_id": "job1", "node_errors": map[string]any{}})
		case r.URL.Path == "/history/job1":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"job1": map[string]any{
					"status": map[string]any{"completed": true, "status_str": "success"},
					"outputs": map[string]any{
						"9": map[string]any{"images": []map[string]string{{"filename": "moe.png", "subfolder": "", "type": "output"}}},
					},
				},
			})
		case r.URL.Path == "/view":
			_, _ = w.Write([]byte("png-bytes"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	cfg := setupTestDir(t, "12_ada")
	cfg.Comfy = ComfyConfig{BaseURL: srv.URL, Checkpoint: "Realistic_Vision_V5.1_fp16-no-ema.safetensors", TimeoutSeconds: 5}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	info, err := GenerateAndStore(ctx, cfg, "12_ada", DrawRequest{Prompt: "a window portrait"})
	if err != nil {
		t.Fatal(err)
	}
	if gotCheckpoint != cfg.Comfy.Checkpoint {
		t.Fatalf("checkpoint sent = %s", gotCheckpoint)
	}
	if !strings.Contains(info.Filename, "__gen__") || !strings.HasPrefix(info.URL, "/api/images/") {
		t.Fatalf("stored = %+v", info)
	}
	file, err := OpenImage(ctx, cfg, info.Filename)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Body.Close()
	if file.Size != int64(len("png-bytes")) {
		t.Fatalf("size = %d", file.Size)
	}
}
