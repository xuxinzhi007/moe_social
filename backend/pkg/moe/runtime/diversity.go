package runtime

import (
	"fmt"
	"strings"

	"backend/model"
)

// 抒情套路词簇（多篇同时出现则视为「同一类内容」）。
var themeClusterWords = []string{
	"星光", "星辰", "灯火", "灯光", "夜空", "深夜", "宁静", "温暖",
	"共鸣", "灵魂", "陪伴", "时光", "璀璨", "温柔", "沉浸",
}

func openingSlice(content string, maxRunes int) string {
	content = strings.TrimSpace(content)
	r := []rune(content)
	if len(r) <= maxRunes {
		return content
	}
	return string(r[:maxRunes])
}

func themeClusterHits(content string) int {
	norm := strings.ToLower(content)
	hits := 0
	for _, w := range themeClusterWords {
		if strings.Contains(norm, strings.ToLower(w)) {
			hits++
		}
	}
	return hits
}

func hasBannedOpening(content string) bool {
	head := openingSlice(content, 32)
	lower := strings.ToLower(head)
	// 「周X的深夜/夜晚，Moe社区…」类固定开场
	if strings.Contains(head, "周") && (strings.Contains(head, "深夜") || strings.Contains(head, "夜晚")) {
		if strings.Contains(lower, "moe") || strings.Contains(head, "社区") {
			return true
		}
	}
	if strings.Contains(lower, "moe") && strings.Contains(head, "社区") {
		if strings.Contains(head, "星光") || strings.Contains(head, "灯火") || strings.Contains(head, "夜空") {
			return true
		}
	}
	if strings.Contains(head, "深夜") && themeClusterHits(content) >= 2 {
		return true
	}
	return false
}

// meaningTooSimilar 判断与近期帖是否「意思差不多」（结构+主题簇）。
func meaningTooSimilar(content string, recent []model.Post, episodes []model.MoeBotEpisode) bool {
	if hasBannedOpening(content) {
		return true
	}
	newOpen := normalizeForCompare(openingSlice(content, 20))
	newTheme := themeClusterHits(content)

	for _, p := range recent {
		if openingOverlap(newOpen, normalizeForCompare(openingSlice(p.Content, 20))) {
			return true
		}
		if newTheme >= 2 && themeClusterHits(p.Content) >= 2 {
			if similarityRatio(normalizeForCompare(content), normalizeForCompare(p.Content)) >= 0.45 {
				return true
			}
		}
	}
	for _, ep := range episodes {
		if openingOverlap(newOpen, normalizeForCompare(openingSlice(ep.Content, 20))) {
			return true
		}
		if newTheme >= 2 && themeClusterHits(ep.Content) >= 2 {
			if similarityRatio(normalizeForCompare(content), normalizeForCompare(ep.Content)) >= 0.45 {
				return true
			}
		}
	}
	return false
}

func openingOverlap(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	if a == b {
		return true
	}
	if len(a) >= 8 && len(b) >= 8 && (strings.HasPrefix(b, a) || strings.HasPrefix(a, b)) {
		return true
	}
	return similarityRatio(a, b) >= 0.62
}

// buildMeaningAwareBlock 告诉模型「近期帖在说什么」以及本次必须避开什么。
func buildMeaningAwareBlock(recent []model.Post, episodes []model.MoeBotEpisode) string {
	var lines []string
	lines = append(lines, "【近期已发 — 语义摘要（意思不要重复）】")
	n := 0
	seenTheme := make(map[string]bool)

	addLine := func(idx int, content string) {
		if n >= 8 {
			return
		}
		summary := summarizePostMeaning(content)
		lines = append(lines, fmt.Sprintf("%d. %s", idx, summary))
		for _, t := range extractThemeLabels(content) {
			seenTheme[t] = true
		}
		n++
	}

	i := 1
	for _, ep := range episodes {
		if n >= 6 {
			break
		}
		addLine(i, ep.Content)
		i++
	}
	for _, p := range recent {
		if n >= 8 {
			break
		}
		addLine(i, p.Content)
		i++
	}
	if n == 0 {
		return "【近期已发】暂无，可自由发挥。"
	}
	var overused []string
	for t := range seenTheme {
		overused = append(overused, t)
	}
	if len(overused) > 0 {
		lines = append(lines, "")
		lines = append(lines, "【近期已用主题 — 本次请换别的】"+strings.Join(overused, "、"))
	}
	lines = append(lines, "")
	lines = append(lines, "【本次硬性要求】")
	lines = append(lines, "- 禁止再用「周X的深夜，Moe社区…星光/灯火」这类开头")
	lines = append(lines, "- 禁止再写深夜抒情+晒画+提问的三段式套路")
	lines = append(lines, "- 换场景：如刚吃完宵夜/排队买咖啡/画材翻车/具体数字/一句吐槽")
	return strings.Join(lines, "\n")
}

func summarizePostMeaning(content string) string {
	content = strings.TrimSpace(content)
	open := openingSlice(content, 28)
	theme := "日常"
	switch {
	case themeClusterHits(content) >= 2:
		theme = "深夜抒情/星光类"
	case strings.Contains(content, "线稿") || strings.Contains(content, "手绘"):
		theme = "手绘练习"
	case strings.Contains(content, "？") || strings.Contains(content, "吗"):
		theme = "提问互动"
	}
	return fmt.Sprintf("开头「%s…」→ %s", open, theme)
}

func extractThemeLabels(content string) []string {
	var out []string
	if themeClusterHits(content) >= 2 {
		out = append(out, "深夜抒情")
	}
	if strings.Contains(content, "手绘") || strings.Contains(content, "线稿") {
		out = append(out, "手绘")
	}
	if strings.Contains(content, "？") || strings.Contains(content, "吗") {
		out = append(out, "结尾提问")
	}
	return out
}
