package gamebiz

import (
	"strings"
)

// CommandKind 玩家指令类型（路由 SSOT，不经过 LLM）。
type CommandKind string

const (
	CmdInspectInventory CommandKind = "inspect_inventory"
	CmdInspectScene     CommandKind = "inspect_scene"
	CmdExploreWorld     CommandKind = "explore_world"
	CmdPickup           CommandKind = "pickup"
	CmdTravel           CommandKind = "travel"
	CmdTalkStart        CommandKind = "talk_start"
	CmdTalkReply        CommandKind = "talk_reply"
	CmdFreeform         CommandKind = "freeform"
)

// Command 结构化玩家指令。
type Command struct {
	Kind   CommandKind
	Raw    string
	Target string // NPC 名或目的地
	Travel travelTarget
}

// parseCommand 规则解析：对话进行中优先续话，移动必须显式。
func parseCommand(raw string, snap *SessionSnapshot) Command {
	raw = strings.TrimSpace(raw)
	lower := strings.ToLower(raw)

	if isExploreWorldAction(raw, lower, ruleBasedIntent(raw)) {
		return Command{Kind: CmdExploreWorld, Raw: raw}
	}
	if isPickupAction(raw) {
		return Command{Kind: CmdPickup, Raw: raw, Target: extractPickupItemName(raw)}
	}
	if isInventoryCheckAction(raw, lower) {
		return Command{Kind: CmdInspectInventory, Raw: raw}
	}
	if isEnvironmentCheckAction(raw, lower, PlayerIntent{Type: "observe"}) {
		return Command{Kind: CmdInspectScene, Raw: raw}
	}
	if isExploreWorldAction(raw, lower, ruleBasedIntent(raw)) {
		return Command{Kind: CmdExploreWorld, Raw: raw}
	}

	exits := decodeExits(snap.Scene.ExitsJSON)
	if target, ok := parseTravelTarget(raw, exits); ok && isExplicitTravelAction(raw) {
		return Command{Kind: CmdTravel, Raw: raw, Target: target.Name, Travel: target}
	}

	if snap.Flags.InDialogue || snap.Flags.LastTalkNPC != "" {
		if isDialogueInput(raw, snap.Flags) {
			target := strings.TrimSpace(snap.Flags.LastTalkNPC)
			if target == "" {
				target = strings.TrimSpace(snap.Flags.PlayerFocus)
			}
			return Command{Kind: CmdTalkReply, Raw: raw, Target: target}
		}
	}

	if isTalkInitAction(raw, ruleBasedIntent(raw)) {
		target := pickTalkTarget(snap.npcViews(), snap.Scene.Name)
		if name := extractNpcNameFromAction(raw, snap.npcViews()); name != "" {
			target = name
		}
		return Command{Kind: CmdTalkStart, Raw: raw, Target: target}
	}

	return Command{Kind: CmdFreeform, Raw: raw}
}

func extractNpcNameFromAction(action string, npcs []NpcView) string {
	for _, npc := range npcs {
		if strings.Contains(action, npc.Name) {
			return npc.Name
		}
	}
	return ""
}

func isTalkInitAction(action string, intent PlayerIntent) bool {
	if intent.Type == "talk" && !strings.Contains(action, "追问") && !strings.Contains(action, "继续") {
		return true
	}
	a := strings.TrimSpace(action)
	return strings.Contains(a, "搭话") || strings.Contains(a, "说话") ||
		strings.Contains(a, "交谈") || strings.Contains(a, "附近的人")
}

func isDialogueInput(action string, flags WorldFlags) bool {
	a := strings.TrimSpace(action)
	if a == "" {
		return false
	}
	if isExplicitTravelAction(a) || isInventoryCheckAction(a, strings.ToLower(a)) {
		return false
	}
	if isDialogueFollowUp(a) || isNpcQuestion(a) ||
		strings.Contains(a, "追问") || strings.Contains(a, "继续") {
		return true
	}
	return flags.InDialogue && utf8RuneCount(a) <= 24
}

func isNpcQuestion(action string) bool {
	a := strings.TrimSpace(action)
	for _, k := range []string{"?", "？", "吗", "呢", "多大", "几岁", "为什么", "怎么", "什么", "谁"} {
		if strings.Contains(a, k) {
			return true
		}
	}
	return false
}

func isExplicitTravelAction(action string) bool {
	a := strings.TrimSpace(action)
	for _, k := range []string{"前往", "走去", "进入", "走向", "出发", "离开", "返回"} {
		if strings.Contains(a, k) {
			return true
		}
	}
	return strings.Contains(a, "方向") && (strings.Contains(a, "走") || strings.Contains(a, "探索"))
}

func isDialogueFollowUp(action string) bool {
	a := strings.TrimSpace(action)
	if utf8RuneCount(a) > 24 {
		return false
	}
	for _, k := range []string{"前往", "走去", "进入", "观察", "检查", "探索", "捡起", "背包", "环境", "周围"} {
		if strings.Contains(a, k) {
			return false
		}
	}
	return true
}

func isInventoryCheckAction(action, lower string) bool {
	if isPickupAction(action) {
		return false
	}
	inspectKeys := []string{
		"检查背包", "查看背包", "打开背包", "看看背包", "清点背包", "翻背包", "瞧瞧背包",
		"物品栏", "行囊", "包里有什么", "背包里",
	}
	for _, k := range inspectKeys {
		if strings.Contains(action, k) {
			return true
		}
	}
	if strings.Contains(lower, "inventory") {
		return strings.Contains(action, "检查") || strings.Contains(action, "查看") || strings.Contains(action, "打开")
	}
	if strings.Contains(lower, "bag") {
		return strings.Contains(action, "check") || strings.Contains(action, "open")
	}
	return strings.Contains(action, "检查") &&
		(strings.Contains(action, "带") || strings.Contains(action, "装") || strings.Contains(action, "物")) &&
		!strings.Contains(action, "捡") && !strings.Contains(action, "拾") && !strings.Contains(action, "放")
}

func isEnvironmentCheckAction(action, lower string, intent PlayerIntent) bool {
	if intent.Type == "observe" {
		return strings.Contains(action, "环境") || strings.Contains(action, "周围") ||
			strings.Contains(action, "四周") || strings.Contains(action, "状况")
	}
	envKeys := []string{"检查环境", "查看环境", "环境", "四周", "周围情况", "周围状况"}
	for _, k := range envKeys {
		if strings.Contains(action, k) || strings.Contains(lower, k) {
			return true
		}
	}
	return strings.Contains(action, "检查") && strings.Contains(action, "环境")
}

func isExploreWorldAction(action, lower string, intent PlayerIntent) bool {
	if strings.Contains(action, "探索世界") || strings.Contains(action, "四处探索") ||
		strings.Contains(action, "到处看看") {
		return true
	}
	return intent.Type == "travel" &&
		(strings.Contains(action, "世界") || strings.Contains(action, "四处") || strings.Contains(action, "逛逛"))
}
