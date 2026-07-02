package gamebiz

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

const seedSceneName = "迷雾小镇"

// NarrativeLine 叙事行（biz 层）。
type NarrativeLine struct {
	Type    string
	Content string
	Name    string
}

// SceneView 场景视图。
type SceneView struct {
	ID          uint
	Name        string
	Description string
	Exits       []string
}

// NpcView NPC 视图。
type NpcView struct {
	ID           uint
	Name         string
	Persona      string
	Favorability int32
}

// ItemView 物品视图。
type ItemView struct {
	ID          uint
	Name        string
	Description string
	InInventory bool
}

// SessionView 会话视图。
type SessionView struct {
	SessionID           uint64
	Scene               SceneView
	Npcs                []NpcView
	Inventory           []ItemView
	GameTime            string
	OverallFavorability int32
	FlagsJSON           string
	PlayerFocus         string
	VisitedScenes       []string
	StoryArcs           []StoryArc
	Opening             []NarrativeLine
	History             []NarrativeLine
}

func parseUserID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, fmt.Errorf("user_id required")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, fmt.Errorf("invalid user_id")
	}
	return uint(n), nil
}

func decodeExits(raw string) []string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	var exits []string
	if err := json.Unmarshal([]byte(raw), &exits); err != nil {
		return nil
	}
	return exits
}

func decodeNpcFavor(raw string) map[string]int {
	out := map[string]int{}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return out
	}
	_ = json.Unmarshal([]byte(raw), &out)
	return out
}

func encodeNpcFavor(m map[string]int) string {
	if len(m) == 0 {
		return "{}"
	}
	b, err := json.Marshal(m)
	if err != nil {
		return "{}"
	}
	return string(b)
}

func averageFavor(m map[string]int, npcs []NpcView) int32 {
	if len(npcs) == 0 {
		return 50
	}
	sum := 0
	for _, npc := range npcs {
		if v, ok := m[fmt.Sprintf("%d", npc.ID)]; ok {
			sum += v
			continue
		}
		sum += int(npc.Favorability)
	}
	return int32(sum / len(npcs))
}
