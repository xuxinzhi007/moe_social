package handdraw

import (
	"testing"
)

func TestRasterPNG_minimalCard(t *testing.T) {
	raw := `{"v":1,"bg":4294309346,"s":[{"c":4286578685,"w":0.02,"p":[[0.1,0.2],[0.8,0.7]]}]}`
	png, err := RasterPNG(raw, 120)
	if err != nil {
		t.Fatal(err)
	}
	if len(png) < 8 || png[0] != 0x89 {
		t.Fatalf("expected PNG header, got %d bytes", len(png))
	}
}

func TestRasterPNG_empty(t *testing.T) {
	if _, err := RasterPNG("", 120); err == nil {
		t.Fatal("expected error for empty input")
	}
}
