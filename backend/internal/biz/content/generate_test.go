package contentbiz

import (
	"errors"
	"strings"
	"testing"
)

func TestNormalizeGenerateInputSupportsOfficialTypes(t *testing.T) {
	for _, contentType := range []string{"text", "image", "video", "code", "article", "story", "poem"} {
		t.Run(contentType, func(t *testing.T) {
			in, err := NormalizeGenerateInput(GenerateInput{Type: " " + contentType + " ", Prompt: " hello "})
			if err != nil {
				t.Fatal(err)
			}
			if in.Type != contentType || in.Prompt != "hello" {
				t.Fatalf("input=%+v", in)
			}
			prompt, ok := ContentSystemPrompt(contentType)
			if !ok || strings.TrimSpace(prompt) == "" {
				t.Fatalf("system prompt missing for %q", contentType)
			}
		})
	}
}

func TestNormalizeGenerateInputRejectsInvalidInput(t *testing.T) {
	if _, err := NormalizeGenerateInput(GenerateInput{Type: "text"}); !errors.Is(err, ErrEmptyPrompt) {
		t.Fatalf("err=%v", err)
	}
	if _, err := NormalizeGenerateInput(GenerateInput{Type: "unknown", Prompt: "hi"}); !errors.Is(err, ErrUnsupportedContentType) {
		t.Fatalf("err=%v", err)
	}
}
