package mediabiz

import (
	"context"
	"strings"
	"testing"
)

func TestSplitImageKeyCategory(t *testing.T) {
	folder, filename, ok := SplitImageKey("12_ada__avatar__1_a.png")
	if !ok || folder != "12_ada/avatar" || filename != "1_a.png" {
		t.Fatalf("split = %q %q ok=%v", folder, filename, ok)
	}
	folder, filename, ok = SplitImageKey("12_ada__old.png")
	if !ok || folder != "12_ada" || filename != "old.png" {
		t.Fatalf("legacy split = %q %q ok=%v", folder, filename, ok)
	}
}

func TestAlbumListHidesOtherCategories(t *testing.T) {
	cfg := setupTestDir(t, "12_ada")
	ctx := context.Background()
	for _, category := range []string{CategoryAvatar, CategoryAlbum, CategoryPost} {
		if _, err := UploadImage(ctx, cfg, UploadInput{
			UserFolder: "12_ada",
			Category:   category,
			OrigName:   category + ".png",
			Reader:     strings.NewReader("img"),
		}); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := UploadImage(ctx, cfg, UploadInput{
		UserFolder: "12_ada",
		OrigName:   "legacy.png",
		Reader:     strings.NewReader("old"),
	}); err != nil {
		t.Fatal(err)
	}

	res, err := ListImages(ctx, cfg, ListImagesInput{UserFolder: "12_ada", Page: 1, PageSize: 20})
	if err != nil {
		t.Fatal(err)
	}
	if res.Total != 2 {
		t.Fatalf("album total = %d, want album + 旧图", res.Total)
	}
	for _, item := range res.Items {
		if strings.Contains(item.Filename, "avatar") || strings.Contains(item.Filename, "post") {
			t.Fatalf("non-album image listed: %s", item.Filename)
		}
	}
}

func TestNormalizeCategoryRejectsUnknown(t *testing.T) {
	if _, err := NormalizeCategory("封面"); err == nil {
		t.Fatal("unknown category should be rejected")
	}
	if got, err := NormalizeCategory("头像"); err != nil || got != CategoryAvatar {
		t.Fatalf("chinese alias = %q %v", got, err)
	}
	got, err := NormalizeCategory("")
	if err != nil || got != CategoryAlbum {
		t.Fatalf("empty category = %q %v", got, err)
	}
}
