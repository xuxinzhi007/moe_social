package companionbiz

import "strings"

const (
	thinkOpenTag  = "<think>"
	thinkCloseTag = "</think>"
)

// thinkStream 在写出 SSE 之前拆开推理和正文。
// Ollama 的 message.thinking 已经单独回调；这里处理仍写在正文里的 <think>。
type thinkStream struct {
	onAnswer  func(string) error
	onThink   func(string) error
	emitThink bool
	inThink   bool
	hold      string
	answer    strings.Builder
}

func (s *thinkStream) push(chunk string) error {
	if chunk == "" {
		return nil
	}
	s.hold += chunk
	for {
		if !s.inThink {
			start := strings.Index(s.hold, thinkOpenTag)
			if start < 0 {
				keep := partialTagSuffix(s.hold, thinkOpenTag)
				ready := s.hold[:len(s.hold)-keep]
				s.hold = s.hold[len(s.hold)-keep:]
				return s.writeAnswer(ready)
			}
			if err := s.writeAnswer(s.hold[:start]); err != nil {
				return err
			}
			s.hold = s.hold[start+len(thinkOpenTag):]
			s.inThink = true
			continue
		}
		end := strings.Index(s.hold, thinkCloseTag)
		if end < 0 {
			keep := partialTagSuffix(s.hold, thinkCloseTag)
			ready := s.hold[:len(s.hold)-keep]
			s.hold = s.hold[len(s.hold)-keep:]
			return s.writeThink(ready)
		}
		if err := s.writeThink(s.hold[:end]); err != nil {
			return err
		}
		s.hold = s.hold[end+len(thinkCloseTag):]
		s.inThink = false
	}
}

// finish 把流结束时还握着的半截标签交出去。
func (s *thinkStream) finish() error {
	rest := s.hold
	s.hold = ""
	if rest == "" {
		return nil
	}
	if s.inThink {
		return s.writeThink(rest)
	}
	return s.writeAnswer(rest)
}

func (s *thinkStream) writeAnswer(text string) error {
	if text == "" {
		return nil
	}
	s.answer.WriteString(text)
	if s.onAnswer == nil {
		return nil
	}
	return s.onAnswer(text)
}

func (s *thinkStream) writeThink(text string) error {
	if text == "" || !s.emitThink || s.onThink == nil {
		return nil
	}
	return s.onThink(text)
}

func partialTagSuffix(text, tag string) int {
	max := len(tag) - 1
	if len(text) < max {
		max = len(text)
	}
	for n := max; n > 0; n-- {
		if strings.HasPrefix(tag, text[len(text)-n:]) {
			return n
		}
	}
	return 0
}
