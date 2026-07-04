package gamebiz

import "testing"

func TestFormatWorldEventLine(t *testing.T) {
	got := formatWorldEventLine("迷雾小镇", "discovery", "钟楼传来异响")
	if got == "" || !contains(got, "迷雾小镇") || !contains(got, "钟楼") {
		t.Fatalf("unexpected event line: %q", got)
	}
}
