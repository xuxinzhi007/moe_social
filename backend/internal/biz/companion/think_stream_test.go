package companionbiz

import (
	"strings"
	"testing"
)

func TestThinkStreamSplitsInlineTags(t *testing.T) {
	var answer, thought strings.Builder
	stream := thinkStream{
		onAnswer:  func(chunk string) error { answer.WriteString(chunk); return nil },
		onThink:   func(chunk string) error { thought.WriteString(chunk); return nil },
		emitThink: true,
	}
	for _, chunk := range []string{"<thi", "nk>先", "想</thi", "nk>你", "好"} {
		if err := stream.push(chunk); err != nil {
			t.Fatalf("push %q: %v", chunk, err)
		}
	}
	if err := stream.finish(); err != nil {
		t.Fatalf("finish: %v", err)
	}
	if thought.String() != "先想" {
		t.Fatalf("thinking = %q", thought.String())
	}
	if answer.String() != "你好" || stream.answer.String() != "你好" {
		t.Fatalf("answer = %q stored %q", answer.String(), stream.answer.String())
	}
}

func TestThinkStreamDropsThinkingWhenSwitchOff(t *testing.T) {
	var answer, thought strings.Builder
	stream := thinkStream{
		onAnswer: func(chunk string) error { answer.WriteString(chunk); return nil },
		onThink:  func(chunk string) error { thought.WriteString(chunk); return nil },
	}
	if err := stream.push("<think>不要给用户看</think>正文"); err != nil {
		t.Fatalf("push: %v", err)
	}
	if err := stream.finish(); err != nil {
		t.Fatalf("finish: %v", err)
	}
	if thought.Len() != 0 {
		t.Fatalf("thinking leaked: %q", thought.String())
	}
	if answer.String() != "正文" {
		t.Fatalf("answer = %q", answer.String())
	}
}
