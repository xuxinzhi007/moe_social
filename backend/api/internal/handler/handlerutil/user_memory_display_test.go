//go:build hybrid

package handlerutil_test

import (
	"testing"

	"backend/api/internal/handler/handlerutil"
	"backend/rpc/pb/moe"
)

func TestBuildUserMemoryDisplayFiltersTechnical(t *testing.T) {
	data := handlerutil.BuildUserMemoryDisplay([]*moe.UserMemory{
		{Id: "1", Key: "device_info:ios", Value: "x", Source: "device_sync"},
		{Id: "2", Key: "hobby", Value: "画画", MemoryType: "preference", UpdatedAt: "2026-01-01"},
	}, nil)

	if len(data.Items) != 1 {
		t.Fatalf("want 1 item, got %d", len(data.Items))
	}
	if data.Items[0].Title != "爱好" {
		t.Fatalf("want title 爱好, got %s", data.Items[0].Title)
	}
	if data.Items[0].Category != "偏好" {
		t.Fatalf("want category 偏好, got %s", data.Items[0].Category)
	}
}
