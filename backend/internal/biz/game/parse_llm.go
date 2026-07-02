package gamebiz

import (
	"encoding/json"
	"strings"
)

var proseTemplateMarkers = []string{
	"150-280字",
	"150-280 字",
	"更新后的时间",
	"\"prose\":",
	"favor_deltas",
	"flags_patch",
	"new_memories",
	"NPC名",
	"npc_name",
	"memory_text",
	"flags_batch",
}

// parseTurnLLMContent 从模型原始输出解析叙事与状态补丁（JSON 或纯文本）。
func parseTurnLLMContent(content string) (turnLLMOutput, bool) {
	content = stripJSONFence(content)
	content = strings.TrimSpace(content)
	if content == "" {
		return turnLLMOutput{}, false
	}

	if out, err := tryParseTurnJSON(content); err == nil {
		if isValidProse(out.Prose) {
			return out, true
		}
	}

	if idx := strings.Index(content, "{"); idx >= 0 {
		if out, err := tryParseTurnJSON(content[idx:]); err == nil && isValidProse(out.Prose) {
			return out, true
		}
	}

	if isValidProse(content) {
		return turnLLMOutput{Prose: content}, true
	}
	return turnLLMOutput{}, false
}

func tryParseTurnJSON(raw string) (turnLLMOutput, error) {
	raw = strings.TrimSpace(raw)
	if end := strings.LastIndex(raw, "}"); end >= 0 {
		raw = raw[:end+1]
	}
	var out turnLLMOutput
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return turnLLMOutput{}, err
	}
	return out, nil
}

func isValidProse(prose string) bool {
	prose = strings.TrimSpace(prose)
	if prose == "" {
		return false
	}
	if len([]rune(prose)) < 12 {
		return false
	}
	if strings.HasPrefix(prose, "{") || strings.HasPrefix(prose, "[") {
		return false
	}
	lower := strings.ToLower(prose)
	for _, marker := range proseTemplateMarkers {
		if strings.Contains(prose, marker) || strings.Contains(lower, strings.ToLower(marker)) {
			return false
		}
	}
	return true
}

func normalizeTurnOutput(out turnLLMOutput, flags WorldFlags, sceneName string) turnLLMOutput {
	out.Prose = strings.TrimSpace(out.Prose)
	if strings.TrimSpace(out.GameTime) == "" {
		out.GameTime = advanceGameTime(flags, sceneName)
	}
	return out
}
