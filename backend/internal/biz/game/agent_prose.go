package gamebiz

import (
	"fmt"
	"strings"
)

// agentProseBlocked 模型常复读的 prompt / JSON 字段，禁止作为玩家可见叙事。
var agentProseBlocked = []string{
	"若本步无需再调工具",
	"否则留空",
	"在此输出叙事",
	"tool_calls",
	"suggested_actions",
	"favor_deltas",
	"简短推理",
	"输出 JSON",
	"无 markdown",
	"第 1 步",
	"第 2 步",
	"第 3 步",
	"第 4 步",
}

// acceptAgentProse 校验 Agent 输出的 prose，过滤 prompt 泄漏与无效短句。
func acceptAgentProse(prose string) (string, bool) {
	prose = strings.TrimSpace(prose)
	if !isValidProse(prose) {
		return "", false
	}
	lower := strings.ToLower(prose)
	for _, marker := range agentProseBlocked {
		if strings.Contains(prose, marker) || strings.Contains(lower, strings.ToLower(marker)) {
			return "", false
		}
	}
	return prose, true
}

// synthesizeAgentProse 工具已执行但模型未给出合法 prose 时，基于事实生成最短叙事（非模板套话）。
func synthesizeAgentProse(action, sceneName string, toolNotes []string, flags WorldFlags) string {
	if len(toolNotes) > 0 {
		last := toolNotes[len(toolNotes)-1]
		if strings.Contains(last, "已移动到") {
			return fmt.Sprintf("你依言行动，来到了【%s】。%s", sceneName, describeSceneMood(flags))
		}
		if strings.Contains(last, "已拾取") || strings.Contains(last, "拾取") {
			return fmt.Sprintf("你照做了——%s。%s", strings.TrimSuffix(last, "。"), describeSceneMood(flags))
		}
		if strings.Contains(last, "开始与") {
			return fmt.Sprintf("%s，%s在%s等你开口。", last, strings.TrimPrefix(last, "开始与"), sceneName)
		}
	}
	return fmt.Sprintf("你在【%s】%s。%s", sceneName, action, describeSceneMood(flags))
}

func describeSceneMood(flags WorldFlags) string {
	mood := strings.TrimSpace(flags.WorldMood)
	if mood == "" {
		return "晨雾仍在缓慢流动。"
	}
	if len([]rune(mood)) > 40 {
		return string([]rune(mood)[:40]) + "…"
	}
	return mood + "。"
}

func dedupeNarrativeLines(lines []NarrativeLine) []NarrativeLine {
	if len(lines) <= 1 {
		return lines
	}
	seen := make(map[string]struct{}, len(lines))
	out := make([]NarrativeLine, 0, len(lines))
	for _, line := range lines {
		key := line.Type + "\x00" + strings.TrimSpace(line.Content)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, line)
	}
	return out
}

// assembleTurnLines 单回合输出 SSOT：事件 → echo → prose（去重）。
func assembleTurnLines(events []NarrativeLine, output turnLLMOutput, playerAction string) []NarrativeLine {
	lines := make([]NarrativeLine, 0, len(events)+2)
	if len(events) > 0 {
		lines = append(lines, events...)
	}
	lines = append(lines, NarrativeLine{Type: "action_echo", Content: playerAction})
	if proseLine := proseLineFromOutput(output); proseLine != nil {
		lines = append(lines, *proseLine)
	}
	return dedupeNarrativeLines(lines)
}

func proseLineFromOutput(output turnLLMOutput) *NarrativeLine {
	prose := strings.TrimSpace(output.Prose)
	prose = sanitizeNarratorProse(prose)
	if parsed, ok := parseTurnLLMContent(prose); ok && isValidProse(parsed.Prose) {
		prose = sanitizeNarratorProse(parsed.Prose)
	} else if !isValidProse(prose) {
		return nil
	}
	line := NarrativeLine{Type: "prose", Content: prose}
	return &line
}
