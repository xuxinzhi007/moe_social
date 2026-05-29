package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFlattenCompatJSON_objectData(t *testing.T) {
	in := []byte(`{"code":0,"message":"ok","success":true,"data":{"user":{"id":"1"},"token":"abc"}}`)
	out, ok := flattenCompatJSON(in)
	if !ok {
		t.Fatal("expected ok")
	}
	var m map[string]any
	if err := json.Unmarshal(out, &m); err != nil {
		t.Fatal(err)
	}
	data, ok := m["data"].(map[string]any)
	if !ok {
		t.Fatalf("data should stay nested, got %v", m["data"])
	}
	if data["token"] != "abc" {
		t.Fatalf("token=%v", data["token"])
	}
}

func TestFlattenCompatJSON_listData(t *testing.T) {
	in := []byte(`{"code":200,"success":true,"message":"ok","data":[{"id":"1"}]}`)
	out, ok := flattenCompatJSON(in)
	if !ok {
		t.Fatal("expected ok")
	}
	var m map[string]any
	if err := json.Unmarshal(out, &m); err != nil {
		t.Fatal(err)
	}
	if _, ok := m["data"].([]any); !ok {
		t.Fatalf("list data should remain under data: %v", m["data"])
	}
}

func TestCompatEnvelopeFilter(t *testing.T) {
	h := compatEnvelopeFilter(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"code":0,"success":true,"message":"ok","data":{"count":3}}`))
	}))
	req := httptest.NewRequest(http.MethodGet, "/api/users/count", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var m map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &m); err != nil {
		t.Fatal(err)
	}
	data, ok := m["data"].(map[string]any)
	if !ok {
		t.Fatalf("data=%v", m["data"])
	}
	if data["count"] != float64(3) {
		t.Fatalf("count=%v", data["count"])
	}
}

func TestCompatEnvelopeFilter_skipsHealth(t *testing.T) {
	h := compatEnvelopeFilter(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	}))
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Body.String() != `{"status":"ok"}` {
		t.Fatalf("body=%s", rec.Body.String())
	}
}
