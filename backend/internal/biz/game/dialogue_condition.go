package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"backend/model"
)

// DialogueCondition 条件对话的触发条件。
type DialogueCondition struct {
	MinFavor      *int     `json:"min_favor,omitempty"`
	MaxFavor      *int     `json:"max_favor,omitempty"`
	HasMemory     string   `json:"has_memory,omitempty"`
	StoryPhaseGte *int     `json:"story_phase_gte,omitempty"`
	RequiredFlags []string `json:"required_flags,omitempty"`
}

// evaluateCondition 逐条评估条件是否全部满足。
func evaluateCondition(cond DialogueCondition, favor int, flags WorldFlags, memories []string) bool {
	if cond.MinFavor != nil && favor < *cond.MinFavor {
		return false
	}
	if cond.MaxFavor != nil && favor > *cond.MaxFavor {
		return false
	}
	if cond.HasMemory != "" {
		found := false
		keyword := strings.TrimSpace(cond.HasMemory)
		for _, m := range memories {
			if strings.Contains(m, keyword) {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	if cond.StoryPhaseGte != nil && flags.StoryPhase < *cond.StoryPhaseGte {
		return false
	}
	if len(cond.RequiredFlags) > 0 {
		flagSet := make(map[string]bool, len(flags.Discovered))
		for _, d := range flags.Discovered {
			flagSet[d] = true
		}
		for _, v := range flags.VisitedScenes {
			flagSet[v] = true
		}
		for _, f := range cond.RequiredFlags {
			if !flagSet[f] {
				return false
			}
		}
	}
	return true
}

// findMatchingDialogue 查找并返回第一个匹配的条件对话模板响应。
// 返回 (responseTemplate, favorDelta, matched)。
func findMatchingDialogue(
	ctx context.Context,
	st Store,
	npcName string,
	npcFavor int,
	flags WorldFlags,
	memories []string,
) (string, int, bool) {
	if st == nil {
		return "", 0, false
	}
	// npcKey 优先按 npc_name 查找，兼容 npc_key 格式
	templates, err := st.FindMatchingDialogueTemplates(ctx, npcName, 10)
	if err != nil {
		slog.Warn("[dialogue_condition] 查询条件对话模板失败", "npc", npcName, "err", err)
		return "", 0, false
	}
	for _, tpl := range templates {
		var cond DialogueCondition
		if err := json.Unmarshal([]byte(tpl.ConditionJSON), &cond); err != nil {
			slog.Warn("[dialogue_condition] 解析条件 JSON 失败", "tpl_id", tpl.ID, "err", err)
			continue
		}
		if evaluateCondition(cond, npcFavor, flags, memories) {
			return tpl.ResponseTemplate, tpl.FavorDelta, true
		}
	}
	return "", 0, false
}

// collectNpcMemoryTexts 收集指定 NPC 的记忆文本列表。
func collectNpcMemoryTexts(ctx context.Context, st Store, playerID, npcID uint) []string {
	if st == nil {
		return nil
	}
	rows, err := st.ListNpcMemories(ctx, playerID, npcID, 20)
	if err != nil {
		return nil
	}
	texts := make([]string, len(rows))
	for i, r := range rows {
		texts[i] = r.MemoryText
	}
	return texts
}

// findNpcIDByName 从 NPC 列表中按名字查找 NPC ID。
func findNpcIDByName(npcs []model.GameNpc, name string) uint {
	name = strings.TrimSpace(name)
	for _, npc := range npcs {
		if npc.Name == name {
			return npc.ID
		}
	}
	return 0
}

// findNpcFavorByName 从 favor map 中按 NPC 名字查找好感度。
func findNpcFavorByName(npcs []model.GameNpc, favor map[string]int, name string) int {
	name = strings.TrimSpace(name)
	for _, npc := range npcs {
		if npc.Name == name {
			key := fmt.Sprintf("%d", npc.ID)
			if v, ok := favor[key]; ok {
				return v
			}
			return npc.BaseFavorability
		}
	}
	return 50
}
