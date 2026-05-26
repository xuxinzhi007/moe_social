package brain

import (
	"strings"
	"unicode/utf8"
)

// ExtractTags 规则打标签（短帖整段，不拆句）。
func ExtractTags(content, moodTag string, styleScore int) []string {
	content = strings.TrimSpace(content)
	var tags []string
	if moodTag != "" {
		tags = append(tags, "mood:"+strings.ToLower(strings.TrimSpace(moodTag)))
	}
	if styleScore >= 3 {
		tags = append(tags, "risk:诗意腔")
	} else {
		tags = append(tags, "tone:口语")
	}
	if strings.ContainsAny(content, "？?") || strings.HasSuffix(content, "吗") || strings.HasSuffix(content, "嘛") {
		tags = append(tags, "type:提问")
	} else {
		tags = append(tags, "type:分享")
	}
	topicRules := []struct {
		keys []string
		tag  string
	}{
		{[]string{"手绘", "速写", "线稿", "上色", "水彩", "板绘"}, "topic:手绘"},
		{[]string{"acg", "番", "cos", "手办", "动漫"}, "topic:ACG"},
		{[]string{"练", "打卡", "进度"}, "topic:练习"},
		{[]string{"周末", "假期", "今天", "昨晚", "早上"}, "topic:日常"},
	}
	lower := strings.ToLower(content)
	for _, r := range topicRules {
		for _, k := range r.keys {
			if strings.Contains(lower, strings.ToLower(k)) {
				tags = append(tags, r.tag)
				break
			}
		}
	}
	if utf8.RuneCountInString(content) > 165 {
		tags = append(tags, "risk:过长")
	}
	if isFormulaicOpening(content) {
		tags = append(tags, "type:套路开场")
	}
	if themeClusterHits(content) >= 2 {
		tags = append(tags, "risk:诗意腔")
	}
	return dedupeTags(tags)
}

func themeClusterHits(content string) int {
	hits := 0
	for _, w := range []string{"星光", "星辰", "灯火", "夜空", "深夜", "宁静", "共鸣", "灵魂", "璀璨", "温柔"} {
		if strings.Contains(content, w) {
			hits++
		}
	}
	return hits
}

func isFormulaicOpening(content string) bool {
	r := []rune(strings.TrimSpace(content))
	if len(r) < 6 {
		return false
	}
	head := string(r)
	if len(r) > 32 {
		head = string(r[:32])
	}
	if strings.Contains(head, "周") && (strings.Contains(head, "深夜") || strings.Contains(head, "夜晚")) {
		if strings.Contains(strings.ToLower(head), "moe") || strings.Contains(head, "社区") {
			return true
		}
	}
	return false
}

func dedupeTags(in []string) []string {
	seen := make(map[string]bool, len(in))
	out := make([]string, 0, len(in))
	for _, t := range in {
		t = strings.TrimSpace(t)
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}

// ParseTagList 解析禁止/偏好标签列表。
func ParseTagList(raw string) []string {
	raw = strings.ReplaceAll(raw, "，", ",")
	var out []string
	for _, part := range strings.FieldsFunc(raw, func(r rune) bool {
		return r == ',' || r == '\n' || r == ';' || r == '；'
	}) {
		if t := strings.TrimSpace(part); t != "" && !strings.HasPrefix(t, "#") {
			out = append(out, t)
		}
	}
	return dedupeTags(out)
}

// TagsConflict 是否命中禁止标签。
func TagsConflict(tags, forbidden []string) []string {
	if len(forbidden) == 0 {
		return nil
	}
	fset := make(map[string]bool, len(forbidden))
	for _, f := range forbidden {
		fset[strings.ToLower(f)] = true
	}
	var hit []string
	for _, t := range tags {
		if fset[strings.ToLower(t)] {
			hit = append(hit, t)
		}
	}
	return hit
}
