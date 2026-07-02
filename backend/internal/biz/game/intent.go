package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/pkg/llminference"
)

// PlayerIntent 玩家行动意图（独立解析 pass）。
type PlayerIntent struct {
	Type      string `json:"type"`
	Target    string `json:"target"`
	Direction string `json:"direction"`
	Summary   string `json:"summary"`
}

func resolvePlayerIntent(ctx context.Context, deps TurnDeps, action, sceneName string, flags WorldFlags) PlayerIntent {
	// 对话进行中：只用规则，避免 LLM 把「你多大了」判成 travel
	if flags.InDialogue || flags.LastTalkNPC != "" {
		intent := ruleBasedIntent(action)
		if isDialogueInput(action, flags) {
			intent.Type = "talk"
			intent.Target = flags.LastTalkNPC
		}
		return intent
	}
	fallback := ruleBasedIntent(action)
	if !deps.Inference.Ready() {
		return fallback
	}
	modelName := strings.TrimSpace(deps.Model)
	if modelName == "" {
		modelName = deps.Inference.DefaultModel
	}
	prompt := fmt.Sprintf(`解析玩家在文字冒险中的行动意图，只输出 JSON：
{"type":"travel|observe|talk|pickup|inventory|interact|emote|unknown","target":"","direction":"","summary":"一句话中文"}

场景：%s
行动：%s

type 说明：travel=移动/前往；observe=观察/检查环境；talk=对话；pickup=拾取；inventory=检查背包/物品栏；interact=与环境/NPC互动；emote=情绪/无实质行动`, sceneName, action)
	content, err := llminference.Chat(ctx, deps.Inference, modelName, []llminference.Message{
		{Role: "system", Content: "只输出合法 JSON，不要 markdown。"},
		{Role: "user", Content: prompt},
	}, llminference.ChatOptions{Temperature: 0.2, MaxTokens: 200})
	if err != nil {
		return fallback
	}
	content = stripJSONFence(content)
	var out PlayerIntent
	if json.Unmarshal([]byte(content), &out) != nil || strings.TrimSpace(out.Type) == "" {
		return fallback
	}
	if strings.TrimSpace(out.Summary) == "" {
		out.Summary = action
	}
	return out
}

func ruleBasedIntent(action string) PlayerIntent {
	lower := strings.ToLower(action)
	intent := PlayerIntent{Type: "interact", Summary: action}
	switch {
	case strings.Contains(lower, "探索") || strings.Contains(lower, "方向"):
		intent.Type = "travel"
	case strings.Contains(lower, "走") || strings.Contains(lower, "前往") || strings.Contains(lower, "进入"):
		// 不用单字「去」，避免「你多大了」误判
		intent.Type = "travel"
		for _, d := range []string{"东", "西", "南", "北"} {
			if strings.Contains(action, d) {
				intent.Direction = d
				break
			}
		}
	case strings.Contains(lower, "看看") || strings.Contains(lower, "观察") || strings.Contains(lower, "周围") ||
		strings.Contains(lower, "环境") || strings.Contains(lower, "四周"):
		intent.Type = "observe"
	case strings.Contains(lower, "捡") || strings.Contains(lower, "拾") || strings.Contains(lower, "拿"):
		intent.Type = "pickup"
	case strings.Contains(lower, "背包") || strings.Contains(lower, "行囊") || strings.Contains(lower, "物品栏"):
		if !isPickupAction(action) {
			intent.Type = "inventory"
		}
	case strings.Contains(lower, "检查") && (strings.Contains(lower, "背包") || strings.Contains(lower, "环境")):
		if strings.Contains(lower, "背包") && !isPickupAction(action) {
			intent.Type = "inventory"
		} else if strings.Contains(lower, "环境") {
			intent.Type = "observe"
		}
	case strings.Contains(lower, "说") || strings.Contains(lower, "问") || strings.Contains(lower, "聊") ||
		strings.Contains(lower, "交谈") || strings.Contains(lower, "说话") ||
		(strings.Contains(lower, "附近") && strings.Contains(lower, "人")):
		intent.Type = "talk"
	case strings.Contains(lower, "哈哈") || strings.Contains(lower, "…"):
		intent.Type = "emote"
	}
	return intent
}

func intentBlock(intent PlayerIntent) string {
	if strings.TrimSpace(intent.Type) == "" {
		return ""
	}
	return fmt.Sprintf("【玩家意图】%s｜目标：%s｜方向：%s｜%s\n",
		intent.Type, intent.Target, intent.Direction, intent.Summary)
}
