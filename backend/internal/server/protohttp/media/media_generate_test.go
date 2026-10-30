package mediahttp

import (
	"testing"

	mediav1 "backend/api/media/v1"
)

func TestGeneratePayloadKeepsRouteAndAddsFullURL(t *testing.T) {
	payload, err := generatePayload(&mediav1.UploadImageReply{
		Id:        "1_xxz__gen__1_gen.png",
		Filename:  "1_xxz__gen__1_gen.png",
		Url:       "/api/images/1_xxz__gen__1_gen.png",
		Size:      536143,
		CreatedAt: "2026-10-30 21:43:03",
	}, "http://cdn.example/media/1_xxz/gen/1_gen.png")
	if err != nil {
		t.Fatal(err)
	}
	if payload["url"] != "/api/images/1_xxz__gen__1_gen.png" {
		t.Fatalf("url = %#v", payload["url"])
	}
	if payload["fullUrl"] != "http://cdn.example/media/1_xxz/gen/1_gen.png" {
		t.Fatalf("fullUrl = %#v", payload["fullUrl"])
	}
}
