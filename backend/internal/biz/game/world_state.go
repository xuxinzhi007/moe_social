package gamebiz

import (
	"encoding/json"
	"strings"
)

// WorldFlags 会话世界状态（存于 game_sessions.flags_json）。
type WorldFlags struct {
	PlayerFocus   string            `json:"player_focus"`
	PlayerPosture string            `json:"player_posture"`
	WorldMood     string            `json:"world_mood"`
	StoryPhase    int               `json:"story_phase"`
	TurnCount     int               `json:"turn_count"`
	Discovered    []string          `json:"discovered"`
	Inventory     []string          `json:"inventory"`
	PendingEvents []string          `json:"pending_events"`
	NpcActivity   map[string]string `json:"npc_activity"`
	VisitedScenes []string          `json:"visited_scenes"`
	StoryArcs     []StoryArc        `json:"story_arcs"`
	LastTalkNPC   string            `json:"last_talk_npc"`
	InDialogue    bool              `json:"in_dialogue"`
}

func defaultWorldFlags() WorldFlags {
	return WorldFlags{
		PlayerFocus:   "广场中央",
		PlayerPosture: "站立",
		WorldMood:     "晨雾弥漫，镇子安静",
		StoryPhase:    0,
		Discovered:    []string{"古老钟楼", "广场长椅"},
		NpcActivity: map[string]string{
			"老人":     "坐在长椅上望着钟楼，抽着烟斗",
			"酒馆老板": "在酒馆门口擦拭木牌",
			"乞丐":     "蜷缩在角落，用破布裹紧身体",
		},
		VisitedScenes: []string{"迷雾小镇"},
	}
}

func decodeWorldFlags(raw string) WorldFlags {
	out := defaultWorldFlags()
	raw = strings.TrimSpace(raw)
	if raw == "" || raw == "{}" {
		return out
	}
	_ = json.Unmarshal([]byte(raw), &out)
	if out.NpcActivity == nil {
		out.NpcActivity = defaultWorldFlags().NpcActivity
	}
	if len(out.Discovered) == 0 {
		out.Discovered = defaultWorldFlags().Discovered
	}
	ensureStoryArcs(&out)
	return out
}

func encodeWorldFlags(f WorldFlags) string {
	b, err := json.Marshal(f)
	if err != nil {
		return "{}"
	}
	return string(b)
}

func (f *WorldFlags) mergePatch(patch map[string]interface{}) {
	if patch == nil {
		return
	}
	if v, ok := patch["player_focus"].(string); ok && strings.TrimSpace(v) != "" {
		f.PlayerFocus = strings.TrimSpace(v)
	}
	if v, ok := patch["player_posture"].(string); ok && strings.TrimSpace(v) != "" {
		f.PlayerPosture = strings.TrimSpace(v)
	}
	if v, ok := patch["world_mood"].(string); ok && strings.TrimSpace(v) != "" {
		f.WorldMood = strings.TrimSpace(v)
	}
	if v, ok := patch["story_phase"].(float64); ok {
		f.StoryPhase = int(v)
	}
	if v, ok := patch["turn_count"].(float64); ok {
		f.TurnCount = int(v)
	}
	if v, ok := patch["last_talk_npc"].(string); ok && strings.TrimSpace(v) != "" {
		f.LastTalkNPC = strings.TrimSpace(v)
	}
	if v, ok := patch["in_dialogue"].(bool); ok {
		f.InDialogue = v
	}
	if v, ok := patch["discovered"].([]interface{}); ok {
		for _, item := range v {
			if s, ok := item.(string); ok && s != "" {
				f.Discovered = appendUnique(f.Discovered, s)
			}
		}
	}
	if v, ok := patch["npc_activity"].(map[string]interface{}); ok {
		if f.NpcActivity == nil {
			f.NpcActivity = map[string]string{}
		}
		for name, act := range v {
			if s, ok := act.(string); ok {
				f.NpcActivity[name] = s
			}
		}
	}
}

func appendUnique(list []string, item string) []string {
	for _, x := range list {
		if x == item {
			return list
		}
	}
	return append(list, item)
}

func npcActivityBlock(flags WorldFlags) string {
	if len(flags.NpcActivity) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【NPC 当前活动】\n")
	for name, act := range flags.NpcActivity {
		b.WriteString("- ")
		b.WriteString(name)
		b.WriteString("：")
		b.WriteString(act)
		b.WriteString("\n")
	}
	return b.String()
}
