package gamebiz

import (
	"context"
	"fmt"
	"strings"
	"unicode/utf8"
)

const maxHistoryTurns = 5

// buildRecentHistoryBlock 将最近回合摘要注入 LLM 提示，保证对话连贯。
func buildRecentHistoryBlock(ctx context.Context, st Store, sessionID uint) string {
	if st == nil {
		return ""
	}
	summaries, err := st.ListRecentTurnLogSummaries(ctx, sessionID, maxHistoryTurns)
	if err != nil || len(summaries) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【近期剧情（必须承接，禁止重复场景描述原文）】\n")
	for _, s := range summaries {
		action := strings.TrimSpace(s.UserAction)
		if action == "" {
			continue
		}
		b.WriteString("玩家：")
		b.WriteString(truncateRunes(action, 80))
		b.WriteString("\n")
		narrative := strings.TrimSpace(s.NarrativePrefix)
		if narrative != "" {
			b.WriteString("叙事：")
			b.WriteString(truncateRunes(narrative, 160))
			b.WriteString("\n")
		}
	}
	return b.String()
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
