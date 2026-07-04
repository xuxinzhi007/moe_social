package gamebiz

import (
	"strings"
	"testing"
)

func TestSanitizeNarratorProseDedupes(t *testing.T) {
	raw := "昏黄的路灯下，老人坐在长椅上。\n\n昏黄的路灯下，老人坐在长椅上。\n\n故事背景\n这是另一个世界"
	got := sanitizeNarratorProse(raw)
	if strings.Count(got, "昏黄的路灯") > 1 {
		t.Fatalf("expected deduped prose, got: %s", got)
	}
	if strings.Contains(got, "故事背景") {
		t.Fatalf("should strip world-doc sections: %s", got)
	}
}

func TestSanitizeNarratorProseDedupesSentences(t *testing.T) {
	raw := "老人抬起头。老人抬起头。他笑了笑。"
	got := sanitizeNarratorProse(raw)
	if strings.Count(got, "老人抬起头") > 1 {
		t.Fatalf("expected sentence dedupe, got: %s", got)
	}
}
