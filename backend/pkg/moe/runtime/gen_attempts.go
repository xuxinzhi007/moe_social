package runtime

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

// GenAttemptOutcome 单次试跑内某次 LLM 生成结果（不跨请求累积）。
type GenAttemptOutcome string

const (
	GenOutcomeOK        GenAttemptOutcome = "ok"
	GenOutcomeDuplicate GenAttemptOutcome = "duplicate"
	GenOutcomeTheme     GenAttemptOutcome = "theme"
	GenOutcomeForbidden GenAttemptOutcome = "forbidden"
	GenOutcomeNovel     GenAttemptOutcome = "novel"
	GenOutcomeLLMError  GenAttemptOutcome = "llm_error"
	GenOutcomeEmpty     GenAttemptOutcome = "empty"
)

// GenAttemptRecord 单次试跑内的一次生成尝试记录。
type GenAttemptRecord struct {
	Attempt int               `json:"attempt"`
	Outcome GenAttemptOutcome `json:"outcome"`
	Snippet string            `json:"snippet,omitempty"`
	Note    string            `json:"note,omitempty"`
}

func genSnippet(content string) string {
	s := strings.TrimSpace(content)
	if s == "" {
		return ""
	}
	return truncateRunes(s, 48)
}

func outcomeLabelZh(o GenAttemptOutcome) string {
	switch o {
	case GenOutcomeOK:
		return "通过"
	case GenOutcomeDuplicate:
		return "与近期帖重复"
	case GenOutcomeTheme:
		return "主题/开头过像"
	case GenOutcomeForbidden:
		return "命中禁止标签"
	case GenOutcomeNovel:
		return "偏剧本/诗意腔"
	case GenOutcomeLLMError:
		return "LLM 调用失败"
	case GenOutcomeEmpty:
		return "正文为空"
	default:
		return string(o)
	}
}

// FormatGenStepDetail 写入流水线 generate 步骤的明细（多行，仅描述本次试跑）。
func FormatGenStepDetail(attempts []GenAttemptRecord, ok bool, source string) string {
	if len(attempts) == 0 {
		return ""
	}
	lines := []string{fmt.Sprintf("本次试跑共生成 %d 次（仅本请求，不跨历史累积）", len(attempts))}
	for _, a := range attempts {
		line := fmt.Sprintf("  %d. %s", a.Attempt, outcomeLabelZh(a.Outcome))
		if s := strings.TrimSpace(a.Snippet); s != "" {
			line += " — 「" + s + "」"
		}
		if n := strings.TrimSpace(a.Note); n != "" {
			line += "（" + n + "）"
		}
		lines = append(lines, line)
	}
	if ok && strings.TrimSpace(source) != "" {
		lines = append(lines, "→ 采用："+source)
	}
	return strings.Join(lines, "\n")
}

// FormatRunDetailFromGen 试跑顶层 detail：请求结束后展示本次生成汇总。
func FormatRunDetailFromGen(attempts []GenAttemptRecord, ok bool, source string, finalErr error) string {
	n := len(attempts)
	if n == 0 {
		if finalErr != nil {
			return finalErr.Error()
		}
		return ""
	}
	if ok {
		rejects := n - 1
		if rejects <= 0 {
			return fmt.Sprintf("本次试跑：生成 1 次即通过 · %s", strings.TrimSpace(source))
		}
		return fmt.Sprintf("本次试跑：生成 %d 次后通过（前 %d 次未过质检）· %s", n, rejects, strings.TrimSpace(source))
	}
	summary := summarizeRejectCounts(attempts)
	msg := fmt.Sprintf("本次试跑：生成 %d 次均未通过", n)
	if summary != "" {
		msg += "（" + summary + "）"
	}
	if finalErr != nil {
		msg += " · " + stripLegacyAttemptPrefix(finalErr.Error())
	}
	return msg
}

func summarizeRejectCounts(attempts []GenAttemptRecord) string {
	counts := make(map[GenAttemptOutcome]int)
	for _, a := range attempts {
		if a.Outcome == GenOutcomeOK {
			continue
		}
		counts[a.Outcome]++
	}
	if len(counts) == 0 {
		return ""
	}
	order := []GenAttemptOutcome{
		GenOutcomeDuplicate, GenOutcomeTheme, GenOutcomeNovel,
		GenOutcomeForbidden, GenOutcomeLLMError, GenOutcomeEmpty,
	}
	var parts []string
	for _, o := range order {
		if c := counts[o]; c > 0 {
			parts = append(parts, fmt.Sprintf("%d×%s", c, outcomeLabelZh(o)))
		}
	}
	return strings.Join(parts, "，")
}

// stripLegacyAttemptPrefix 去掉旧版「第 N 次重试」前缀，避免与新版汇总重复。
func stripLegacyAttemptPrefix(msg string) string {
	msg = strings.TrimSpace(msg)
	for attempt := 1; attempt <= maxGenerateAttempts+2; attempt++ {
		prefix := fmt.Sprintf("生成内容与近期帖重复，第 %d 次重试", attempt)
		if strings.HasPrefix(msg, prefix) {
			return "末次：与近期帖重复"
		}
		prefix = fmt.Sprintf("与近期动态意思太像（同开头/同主题），第 %d 次重试", attempt)
		if strings.HasPrefix(msg, prefix) {
			return "末次：与近期动态意思太像"
		}
	}
	if strings.Contains(msg, "第 ") && strings.Contains(msg, "次重试") {
		return "末次质检未通过"
	}
	return msg
}

func genAttemptNote(err error) string {
	if err == nil {
		return ""
	}
	s := strings.TrimSpace(err.Error())
	if utf8.RuneCountInString(s) > 80 {
		return truncateRunes(s, 80)
	}
	return s
}
