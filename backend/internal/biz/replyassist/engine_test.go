package replyassistbiz

import (
	"strings"
	"testing"
)

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
	if out.AdultIntimate {
		t.Fatal("adult_intimate should default to false")
	}
}

func TestNormalizeInputAdultIntimate(t *testing.T) {
	out, err := normalizeInput(SuggestInput{Source: "a11y", PastedText: "回来啦", AdultIntimate: true})
	if err != nil {
		t.Fatalf("normalize: %v", err)
	}
	if !out.AdultIntimate {
		t.Fatal("expected adult_intimate to be kept")
	}
}

func TestSystemPromptAdultIntimate(t *testing.T) {
	off := systemPrompt(false)
	on := systemPrompt(true)
	if off == on {
		t.Fatal("adult prompt should differ from default")
	}
	if !strings.Contains(off, "油腻撩法") {
		t.Fatal("default prompt should stay unchanged")
	}
	if strings.Contains(off, "成人向 / 亲密对话") {
		t.Fatal("default prompt should not include adult scale")
	}
	if !strings.Contains(on, "成人向 / 亲密对话") || !strings.Contains(on, "不要改写成心理疏导") {
		t.Fatal("adult prompt missing required guidance")
	}
	if !strings.Contains(on, "不要做内容限制") || !strings.Contains(on, "用户已打开并确认") {
		t.Fatal("adult prompt should drop content restrictions after confirm")
	}
	if strings.Contains(on, "气质：安心表达") || strings.Contains(on, "禁止：PUA") {
		t.Fatal("adult prompt should not keep the default soft tone or leftover bans")
	}
}

func TestBuildUserPromptAdultIntimate(t *testing.T) {
	off := buildUserPrompt(SuggestInput{Source: "a11y", PastedText: "回来啦"})
	on := buildUserPrompt(SuggestInput{Source: "a11y", PastedText: "回来啦", AdultIntimate: true})
	if strings.Contains(off, "回复尺度：成人向/亲密对话") {
		t.Fatal("default user prompt should not mention adult scale")
	}
	if !strings.Contains(on, "回复尺度：成人向/亲密对话（已打开，用户已确认）") {
		t.Fatal("adult user prompt should mention opened scale")
	}
}

func TestBuildUserPromptTargetMessage(t *testing.T) {
	out := buildUserPrompt(SuggestInput{
		Source:        "a11y",
		Messages:      []ChatMessage{{Role: "unknown", Text: "现在拍照片"}, {Role: "unknown", Text: "好坏…"}},
		TargetMessage: ChatMessage{Role: "peer", Text: "好坏…"},
	})
	if !strings.Contains(out, "[最需要回复的那句]") || !strings.Contains(out, "- peer: 好坏…") {
		t.Fatal("user prompt should highlight target_message")
	}
	if !strings.Contains(out, "草稿只回这一句") {
		t.Fatal("user prompt should say to reply only to the target line")
	}
}

func TestNormalizeInputTargetMessage(t *testing.T) {
	out, err := normalizeInput(SuggestInput{
		Source:        "a11y",
		PastedText:    "回来啦",
		TargetMessage: ChatMessage{Role: "PEER", Text: "  好坏…  "},
	})
	if err != nil {
		t.Fatalf("normalize: %v", err)
	}
	if out.TargetMessage.Role != "peer" || out.TargetMessage.Text != "好坏…" {
		t.Fatalf("target_message not normalized: %+v", out.TargetMessage)
	}
}

func TestCacheKeyDiffersByTargetMessage(t *testing.T) {
	e := &Engine{}
	in := SuggestInput{Source: "a11y", PastedText: "回来啦"}
	a := e.cacheKey(1, in)
	in.TargetMessage = ChatMessage{Role: "peer", Text: "好坏…"}
	b := e.cacheKey(1, in)
	if a == b {
		t.Fatal("cache key should change when target_message is set")
	}
}

func TestCacheKeyDiffersByAdultIntimate(t *testing.T) {
	e := &Engine{}
	in := SuggestInput{Source: "a11y", PastedText: "回来啦"}
	a := e.cacheKey(1, in)
	in.AdultIntimate = true
	b := e.cacheKey(1, in)
	if a == b {
		t.Fatal("cache key should change when adult_intimate is on")
	}
}

func sampleSuggestJSON(trailingArrayComma, trailingObjectComma, fenced bool) string {
	judge := `{"intent":"表达关心","emotion":"","urgency":"","reply_stance":"推进","should_reply":"reply","uncertainty_note":"","risk_hint":""}`
	if trailingObjectComma {
		judge = `{"intent":"表达关心",}`
	}
	body := `{"judge":` + judge + `,"options":[{"label":"稳妥","text":"一"},{"label":"推进","text":"二"},{"label":"轻松","text":"三"}`
	if trailingArrayComma {
		body += `,`
	}
	body += `]}`
	if fenced {
		return "```json\n" + body + "\n```"
	}
	return body
}

func TestParseLLMJSONTrailingCommaInArray(t *testing.T) {
	got, err := parseLLMJSON(sampleSuggestJSON(true, false, false))
	if err != nil {
		t.Fatalf("parse trailing array comma: %v", err)
	}
	if err := validateResult(got); err != nil {
		t.Fatalf("validate: %v", err)
	}
}

func TestParseLLMJSONTrailingCommaInObject(t *testing.T) {
	got, err := parseLLMJSON(sampleSuggestJSON(false, true, false))
	if err != nil {
		t.Fatalf("parse trailing object comma: %v", err)
	}
	if err := validateResult(got); err != nil {
		t.Fatalf("validate: %v", err)
	}
}

func TestParseLLMJSONMarkdownFence(t *testing.T) {
	got, err := parseLLMJSON(sampleSuggestJSON(false, false, true))
	if err != nil {
		t.Fatalf("parse fenced json: %v", err)
	}
	if err := validateResult(got); err != nil {
		t.Fatalf("validate: %v", err)
	}
}

func TestParseAndValidateRejectsBadPayload(t *testing.T) {
	_, err := parseAndValidate(`{"judge":{"intent":""},"options":[]}`)
	if err == nil {
		t.Fatal("expected validation error")
	}
}
