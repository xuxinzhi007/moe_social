package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"unicode/utf8"

	"backend/model"
)

const maxHistoryTurns = 10

// buildRecentHistoryBlock 将最近回合注入 LLM 提示，保证对话连贯。
func buildRecentHistoryBlock(ctx context.Context, st Store, sessionID uint) string {
	if st == nil {
		return ""
	}
	logs, err := st.ListRecentTurnLogs(ctx, sessionID, maxHistoryTurns)
	if err != nil || len(logs) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【近期剧情（必须承接，禁止重复场景描述原文）】\n")
	for _, log := range logs {
		action := strings.TrimSpace(log.UserAction)
		if action == "" {
			continue
		}
		b.WriteString("玩家：")
		b.WriteString(truncateRunes(action, 80))
		b.WriteString("\n")
		prose := extractProseFromTurnLog(log)
		if prose != "" {
			b.WriteString("叙事：")
			b.WriteString(truncateRunes(prose, 160))
			b.WriteString("\n")
		}
	}
	return b.String()
}

func extractProseFromTurnLog(log model.GameTurnLog) string {
	if strings.TrimSpace(log.SystemNarrative) == "" {
		return ""
	}
	var lines []NarrativeLine
	if err := json.Unmarshal([]byte(log.SystemNarrative), &lines); err != nil {
		return ""
	}
	var parts []string
	for _, line := range lines {
		if line.Type == "prose" || line.Type == "npc" || line.Type == "system" {
			c := strings.TrimSpace(line.Content)
			if c != "" {
				parts = append(parts, c)
			}
		}
	}
	return strings.Join(parts, " ")
}

func truncateRunes(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	var b strings.Builder
	n := 0
	for _, r := range s {
		if n >= max {
			b.WriteString("…")
			break
		}
		b.WriteRune(r)
		n++
	}
	return b.String()
}

func buildDialogueContextBlock(flags WorldFlags) string {
	npc := strings.TrimSpace(flags.LastTalkNPC)
	if npc == "" {
		npc = strings.TrimSpace(flags.PlayerFocus)
	}
	if npc == "" || strings.Contains(npc, "广场") || strings.Contains(npc, "方向") {
		return ""
	}
	block := fmt.Sprintf("【当前对话对象】%s", npc)
	if flags.InDialogue {
		block += "（对话进行中：玩家输入应视为对该 NPC 的回应）"
	}
	return block + "\n"
}
