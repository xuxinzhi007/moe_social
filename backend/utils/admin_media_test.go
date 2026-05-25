package utils

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAdminMediaStorageParts(t *testing.T) {
	key, folder, file, ok := adminMediaStorageParts("12_alice/1716_photo.jpg")
	if !ok || key != "12_alice__1716_photo.jpg" || folder != "12_alice" || file != "1716_photo.jpg" {
		t.Fatalf("subdir: key=%q folder=%q file=%q ok=%v", key, folder, file, ok)
	}
	_, _, _, ok = adminMediaStorageParts("only.jpg")
	if ok {
		t.Fatal("root file without __ should be skipped")
	}
}

func TestListAndDeleteAdminMediaImages(t *testing.T) {
	root := t.TempDir()
	userDir := filepath.Join(root, "9_tester")
	if err := os.MkdirAll(userDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(userDir, "100_a.png"), []byte("png"), 0o644); err != nil {
		t.Fatal(err)
	}
	otherDir := filepath.Join(root, "1_xxz")
	if err := os.MkdirAll(otherDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(otherDir, "200_b.jpg"), []byte("jpg"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(userDir, "100_hand_draw_thumb.png"), []byte("png"), 0o644); err != nil {
		t.Fatal(err)
	}

	items, owners, total, err := ListAdminMediaImages(root, "http://example.com", 1, 10, "", "", "")
	if err != nil {
		t.Fatal(err)
	}
	if total != 3 || len(items) != 3 || len(owners) != 2 {
		t.Fatalf("list all: total=%d items=%d owners=%d", total, len(items), len(owners))
	}

	items, _, total, err = ListAdminMediaImages(root, "http://example.com", 1, 10, "", "", "gallery")
	if err != nil || total != 2 {
		t.Fatalf("gallery filter: total=%d err=%v", total, err)
	}
	items, _, total, err = ListAdminMediaImages(root, "http://example.com", 1, 10, "", "", "hand_draw")
	if err != nil || total != 1 || items[0].MediaKind != "hand_draw" {
		t.Fatalf("hand_draw filter: total=%d kind=%q", total, items[0].MediaKind)
	}

	items, owners, total, err = ListAdminMediaImages(root, "http://example.com", 1, 10, "", "1_xxz", "")
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(items) != 1 || items[0].OwnerFolder != "1_xxz" {
		t.Fatalf("filter owner: total=%d folder=%s", total, items[0].OwnerFolder)
	}
	if len(owners) != 2 {
		t.Fatalf("owners should include all folders: %d", len(owners))
	}

	if err := DeleteAdminMediaImage(root, items[0].Filename); err != nil {
		t.Fatal(err)
	}
	_, _, total, err = ListAdminMediaImages(root, "http://example.com", 1, 10, "", "1_xxz", "")
	if err != nil {
		t.Fatal(err)
	}
	if total != 0 {
		t.Fatalf("after delete total=%d", total)
	}
}

func TestClassifyAdminMediaKind(t *testing.T) {
	if ClassifyAdminMediaKind("1779623642_hand_draw_thumb.png") != "hand_draw" {
		t.Fatal("expected hand_draw")
	}
	if ClassifyAdminMediaKind("1777310070_scaled_6941.jpg") != "gallery" {
		t.Fatal("expected gallery")
	}
}

func TestDeleteAdminMediaImageInvalid(t *testing.T) {
	root := t.TempDir()
	if err := DeleteAdminMediaImage(root, "../escape"); err == nil {
		t.Fatal("expected error for path traversal")
	}
}
