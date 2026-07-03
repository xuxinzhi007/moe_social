package gamebiz

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
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

// --- 双写架构：WorldFlags <-> game_world_states 独立字段表 ---

// writeWorldStateToDB 将 WorldFlags 写入新表（双写），任一失败不影响游戏运行。
func writeWorldStateToDB(ctx context.Context, st Store, sessionID uint, flags WorldFlags) {
	if st == nil {
		return
	}
	row := &model.GameWorldState{
		SessionID:     sessionID,
		PlayerFocus:   flags.PlayerFocus,
		PlayerPosture: flags.PlayerPosture,
		WorldMood:     flags.WorldMood,
		StoryPhase:    flags.StoryPhase,
		TurnCount:     flags.TurnCount,
		LastTalkNpc:   flags.LastTalkNPC,
		InDialogue:    flags.InDialogue,
	}
	if err := st.UpsertWorldState(ctx, row); err != nil {
		moelog.Warnf("game: writeWorldStateToDB upsert session=%d: %v", sessionID, err)
	}
	for _, item := range flags.Discovered {
		if err := st.UpsertDiscoveredItem(ctx, &model.GameDiscoveredItem{
			SessionID: sessionID,
			ItemName:  item,
		}); err != nil {
			moelog.Warnf("game: writeWorldStateToDB discovered session=%d: %v", sessionID, err)
		}
	}
}

// readWorldFlagsFromDB 从新表加载 WorldFlags，不存在时返回 nil。
func readWorldFlagsFromDB(ctx context.Context, st Store, sessionID uint) *WorldFlags {
	if st == nil {
		return nil
	}
	ws, err := st.GetWorldState(ctx, sessionID)
	if err != nil || ws == nil {
		return nil
	}
	flags := &WorldFlags{
		PlayerFocus:   ws.PlayerFocus,
		PlayerPosture: ws.PlayerPosture,
		WorldMood:     ws.WorldMood,
		StoryPhase:    ws.StoryPhase,
		TurnCount:     ws.TurnCount,
		LastTalkNPC:   ws.LastTalkNpc,
		InDialogue:    ws.InDialogue,
	}
	items, err := st.ListDiscoveredItems(ctx, sessionID)
	if err == nil {
		for _, it := range items {
			flags.Discovered = append(flags.Discovered, it.ItemName)
		}
	}
	activities, err := st.ListNpcActivities(ctx, sessionID)
	if err == nil {
		flags.NpcActivity = map[string]string{}
		for _, a := range activities {
			flags.NpcActivity[a.SceneName] = a.Activity
		}
	}
	if flags.NpcActivity == nil {
		flags.NpcActivity = defaultWorldFlags().NpcActivity
	}
	if len(flags.Discovered) == 0 {
		flags.Discovered = defaultWorldFlags().Discovered
	}
	ensureStoryArcs(flags)
	return flags
}

// backfillWorldStateFromFlags 将 flags_json 反序列化的结果回填新表（首次迁移）。
func backfillWorldStateFromFlags(ctx context.Context, st Store, sessionID uint, flags WorldFlags) {
	if st == nil || sessionID == 0 {
		return
	}
	writeWorldStateToDB(ctx, st, sessionID, flags)
}

// writeNpcActivitiesToDB 将 NpcActivity map 写入新表（用 NPC 名称查找 ID）。
func writeNpcActivitiesToDB(ctx context.Context, st Store, sessionID uint, sceneName string, npcs []model.GameNpc, npcActivity map[string]string) {
	if st == nil || len(npcActivity) == 0 {
		return
	}
	npcIDByName := map[string]uint{}
	for _, npc := range npcs {
		npcIDByName[npc.Name] = npc.ID
	}
	for name, act := range npcActivity {
		npcID, ok := npcIDByName[name]
		if !ok || npcID == 0 {
			continue
		}
		if err := st.UpsertNpcActivity(ctx, &model.GameNpcActivity{
			SessionID: sessionID,
			NpcID:     npcID,
			Activity:  act,
			SceneName: sceneName,
			UpdatedAt: time.Now(),
		}); err != nil {
			moelog.Warnf("game: writeNpcActivitiesToDB session=%d npc=%s: %v", sessionID, name, err)
		}
	}
}
