package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	postv1 "backend/api/post/v1"

	"github.com/go-kratos/kratos/v2/errors"
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
	posts, ok := body["posts"].([]any)
	if !ok || len(posts) != 1 {
		t.Fatalf("posts=%v", body["posts"])
	}
	if body["total"].(float64) != 1 {
		t.Fatalf("total=%v", body["total"])
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
