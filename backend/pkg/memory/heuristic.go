package memory

import (
	"regexp"
	"strings"
)

// HeuristicItem 规则提取的一条记忆。
type HeuristicItem struct {
	Key        string
	Value      string
	MemoryType string
}

var (
	reUserRename1 = regexp.MustCompile(`我(?:现在|已经|又)?改(?:了|成)?名(?:叫|为|成)?[「"“]?([^」"”\s，。!！?？\n]+)`)
	reUserRename2 = regexp.MustCompile(`我(?:现在)?叫[「"“]?([^」"”\s，。!！?？\n]+)`)
	reCallMe      = regexp.MustCompile(`(?:请)?叫我[「"“]?([^」"”\s，。!！?？\n]+)`)
	reMyName      = regexp.MustCompile(`我的名字(?:是|叫)[「"“]?([^」"”\s，。!！?？\n]+)`)
	reRememberMe  = regexp.MustCompile(`请记住[，,]?我(?:叫|是)[「"“]?([^」"”\s，。!！?？\n]+)`)
	rePreference  = regexp.MustCompile(`记住[：:]?\s*(?:我)?(?:喜欢|爱|讨厌|不爱)([^，。!！?？\n]{1,40})`)
	reAIPersona   = regexp.MustCompile(`^你(?:现在|以后|今晚)?(?:叫|是)`)
)

// HeuristicExtractFromUserMessage 从用户消息提取可持久化事实（与 Flutter 规则对齐）。
func HeuristicExtractFromUserMessage(text string) []HeuristicItem {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	if reAIPersona.MatchString(text) {
		return nil
	}
	var out []HeuristicItem
	if name := matchFirst(reUserRename1, text); name != "" {
		out = append(out, HeuristicItem{Key: "user_nickname", Value: name, MemoryType: "identity"})
	} else if name := matchFirst(reUserRename2, text); name != "" {
		out = append(out, HeuristicItem{Key: "user_nickname", Value: name, MemoryType: "identity"})
	} else if name := matchFirst(reCallMe, text); name != "" {
		out = append(out, HeuristicItem{Key: "user_nickname", Value: name, MemoryType: "identity"})
	} else if name := matchFirst(reMyName, text); name != "" {
		out = append(out, HeuristicItem{Key: "user_nickname", Value: name, MemoryType: "identity"})
	} else if name := matchFirst(reRememberMe, text); name != "" {
		out = append(out, HeuristicItem{Key: "user_nickname", Value: name, MemoryType: "identity"})
	}
	if m := rePreference.FindStringSubmatch(text); len(m) >= 2 {
		v := cleanHeuristicName(m[1])
		if v != "" {
			out = append(out, HeuristicItem{Key: "user_preference", Value: v, MemoryType: "preference"})
		}
	}
	return out
}

func matchFirst(re *regexp.Regexp, text string) string {
	m := re.FindStringSubmatch(text)
	if len(m) < 2 {
		return ""
	}
	return cleanHeuristicName(m[1])
}

func cleanHeuristicName(raw string) string {
	name := strings.TrimSpace(raw)
	name = strings.Trim(name, `「」""“”`)
	name = strings.TrimRight(name, "吧呢啊呀")
	if name == "" || len([]rune(name)) > 24 {
		return ""
	}
	return name
}
