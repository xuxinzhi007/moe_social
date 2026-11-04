package replyassistbiz

import "testing"

func TestSafetyBlockedReason(t *testing.T) {
	payload := llmPayload{
		Judge: JudgeSummary{Intent: "对方在试探"},
		Options: []Option{
			{Label: "稳妥", Text: "好的"},
			{Label: "推进", Text: "PUA 话术"},
			{Label: "轻松", Text: "哈哈"},
		},
	}
	blocked, reason := safetyBlockedReason(payload)
	if !blocked || reason == "" {
		t.Fatalf("expected safety block, got blocked=%v reason=%q", blocked, reason)
	}
}

func TestNormalizeInputRequiresContent(t *testing.T) {
	_, err := normalizeInput(SuggestInput{})
	if err == nil {
		t.Fatal("expected error for empty input")
	}
}

func TestNormalizeInputPaste(t *testing.T) {
	out, err := normalizeInput(SuggestInput{Source: "paste", PastedText: "你好"})
	if err != nil {
		t.Fatalf("normalize: %v", err)
	}
	if out.Source != "paste" || out.PastedText != "你好" {
		t.Fatalf("unexpected normalized input: %+v", out)
	}
}
