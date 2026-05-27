package runtime

import (
	"errors"
	"strings"
	"testing"
)

func TestFormatRunDetailFromGen_successAfterRetries(t *testing.T) {
	attempts := []GenAttemptRecord{
		{Attempt: 1, Outcome: GenOutcomeDuplicate, Snippet: "a"},
		{Attempt: 2, Outcome: GenOutcomeTheme, Snippet: "b"},
		{Attempt: 3, Outcome: GenOutcomeOK, Snippet: "c"},
	}
	got := FormatRunDetailFromGen(attempts, true, "llm#3", nil)
	if !strings.Contains(got, "生成 3 次后通过") {
		t.Fatalf("unexpected: %q", got)
	}
	if strings.Contains(got, "第 3 次重试") {
		t.Fatalf("should not use legacy retry wording: %q", got)
	}
}

func TestFormatRunDetailFromGen_allFailed(t *testing.T) {
	attempts := []GenAttemptRecord{
		{Attempt: 1, Outcome: GenOutcomeDuplicate},
		{Attempt: 2, Outcome: GenOutcomeDuplicate},
	}
	got := FormatRunDetailFromGen(attempts, false, "", errors.New("与近期帖重复"))
	if !strings.Contains(got, "生成 2 次均未通过") {
		t.Fatalf("unexpected: %q", got)
	}
	if !strings.Contains(got, "2×与近期帖重复") {
		t.Fatalf("missing reject summary: %q", got)
	}
}
