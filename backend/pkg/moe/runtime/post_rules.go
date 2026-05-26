package runtime

import (
	"strings"

	"backend/model"
)

// defaultPostRules 未配置时使用的内置硬性规则（可在后台 post_rules 覆盖/追加）。
func defaultPostRules() []string {
	return []string{
		"用第一人称「我」，像真人发的朋友圈，不要官方播报腔",
		"正文必须包含至少 1 个具体细节（在做什么/用了什么/一个小数字/地点/时间）",
		"可以带 0～2 个 emoji，允许口语、吐槽、轻松提问结尾",
		"禁止开头：「大家好」「今日也在」「深夜时分」等套路句",
		"禁止排比抒情、剧本旁白、*动作*、称呼读者「你」来叙事",
		"字数 50～140 字，一句话能说清就别写长句堆砌",
	}
}

// parsePostRules 每行一条；# 开头为注释。
func parsePostRules(raw string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var out []string
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		out = append(out, line)
	}
	return out
}

// formatPostRulesBlock 注入 LLM 的【硬性规则】段落。
func formatPostRulesBlock(rt model.MoeAgentRuntime) string {
	rules := parsePostRules(rt.PostRules)
	if len(rules) == 0 {
		rules = defaultPostRules()
	}
	lines := make([]string, 0, len(rules)+1)
	lines = append(lines, "【硬性规则 — 必须全部遵守】")
	for i, r := range rules {
		lines = append(lines, strings.TrimSpace(strings.TrimPrefix(r, "- ")))
		if i > 12 {
			break
		}
	}
	return strings.Join(lines, "\n")
}
