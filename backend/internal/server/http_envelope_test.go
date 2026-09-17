package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	platformv1 "backend/api/platform/v1"
	postv1 "backend/api/post/v1"
	platformhttp "backend/internal/server/protohttp/platform"
	llmapp "backend/internal/service/llm"

	"github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func TestEnvelopeResponseEncoder_getPosts(t *testing.T) {
	t.Parallel()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/posts", nil)

	err := EnvelopeResponseEncoder(rec, req, &postv1.GetPostsReply{
		Posts: []*postv1.Post{{Id: "1", Content: "hi"}},
		Total: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("status=%d", rec.Code)
	}

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["success"] != true {
		t.Fatalf("success=%v", body["success"])
	}
	if body["code"].(float64) != 200 {
		t.Fatalf("code=%v", body["code"])
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("data=%v", body["data"])
	}
	posts, ok := data["posts"].([]any)
	if !ok || len(posts) != 1 {
		t.Fatalf("posts=%v", data["posts"])
	}
	if data["total"].(float64) != 1 {
		t.Fatalf("total=%v", data["total"])
	}
}

func TestEnvelopeErrorEncoder(t *testing.T) {
	t.Parallel()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/posts", nil)

	EnvelopeErrorEncoder(rec, req, errors.New(404, "POST_NOT_FOUND", "帖子不存在"))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status=%d", rec.Code)
	}

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["success"] != false {
		t.Fatalf("success=%v", body["success"])
	}
	if body["reason"] != "POST_NOT_FOUND" {
		t.Fatalf("reason=%v", body["reason"])
	}
}

func TestLlmCreateAgentReturnsFailureEnvelope(t *testing.T) {
	t.Parallel()
	srv := khttp.NewServer(
		khttp.ResponseEncoder(EnvelopeResponseEncoder),
		khttp.ErrorEncoder(EnvelopeErrorEncoder),
	)
	platformv1.RegisterPlatformHTTPServer(srv, platformhttp.New(platformhttp.Deps{
		LLMApp: llmapp.New(nil, llmapp.Deps{}),
	}))
	httpServer := httptest.NewServer(srv)
	defer httpServer.Close()

	resp, err := http.Post(httpServer.URL+"/api/llm/agents", "application/json",
		strings.NewReader(`{"name":"test-agent","base_model":"test-model","system_prompt":"be kind"}`))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusNotImplemented || body["success"] != false || body["code"] != float64(http.StatusNotImplemented) {
		t.Fatalf("status=%d body=%v", resp.StatusCode, body)
	}
	if body["reason"] != "LLM_AGENT_CREATE_FAILED" || body["message"] != "当前后端尚不支持创建或同步服务器模型" {
		t.Fatalf("body=%v", body)
	}
	if _, ok := body["data"]; ok {
		t.Fatalf("failure must not be nested in a success payload: %v", body)
	}
}
