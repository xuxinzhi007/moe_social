package gamebiz

import (
	"fmt"

	"backend/model"
)

func npcViewsFromModels(npcs []model.GameNpc, favor map[string]int) []NpcView {
	out := make([]NpcView, 0, len(npcs))
	for _, npc := range npcs {
		fav := npc.BaseFavorability
		if v, ok := favor[fmt.Sprintf("%d", npc.ID)]; ok {
			fav = v
		}
		out = append(out, NpcView{
			ID:           npc.ID,
			Name:         npc.Name,
			Persona:      npc.Persona,
			Favorability: int32(fav),
		})
	}
	return out
}

func sceneViewFromModel(row model.GameScene) SceneView {
	return SceneView{
		ID:          row.ID,
		Name:        row.Name,
		Description: row.Description,
		Exits:       decodeExits(row.ExitsJSON),
	}
}

func defaultOpening(sceneName string) []NarrativeLine {
	return []NarrativeLine{
		{Type: "prose", Content: fmt.Sprintf("🌅 你醒来时，发现自己站在【%s】的广场上。晨雾刚刚散去，一座古老的钟楼在雾中若隐若现。镇口的牌匾在微风中轻轻摇晃。", sceneName)},
		{Type: "prose", Content: "这是一个开放世界——你可以输入任何行动：去任何方向、遇见任何人、捡起任何物品，世界会随之生成与演化。"},
		{Type: "hint", Content: "试试自由输入，例如：「往东走进森林」或「和老人搭话」"},
	}
}

func defaultSuggestedActions(sceneName string, flags WorldFlags) []string {
	_ = sceneName
	return []string{
		"观察周围",
		"和附近的人说话",
		"往一个方向探索",
	}
}
