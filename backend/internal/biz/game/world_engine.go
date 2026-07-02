package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/model"
)

type turnLLMScene struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	SceneType   string   `json:"scene_type"`
	Exits       []string `json:"exits"`
	MovePlayer  bool     `json:"move_player"`
}

type turnLLMNpcSpawn struct {
	Name    string `json:"name"`
	Persona string `json:"persona"`
	Role    string `json:"role"`
}

type turnLLMItemSpawn struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Takeable    bool   `json:"takeable"`
	PickedUp    bool   `json:"picked_up"`
}

type turnLLMEvent struct {
	Type        string `json:"type"`
	Description string `json:"description"`
}

// applyWorldMutations 根据 LLM 结构化输出扩展世界（场景/NPC/物品/事件）。
func applyWorldMutations(
	ctx context.Context,
	st Store,
	sess *model.GameSession,
	scene *model.GameScene,
	npcs *[]model.GameNpc,
	flags *WorldFlags,
	output turnLLMOutput,
) ([]NarrativeLine, error) {
	var extras []NarrativeLine

	if output.NewScene != nil {
		if moved, err := applyNewScene(ctx, st, sess, scene, npcs, flags, *output.NewScene); err != nil {
			return extras, err
		} else if moved {
			extras = append(extras, NarrativeLine{
				Type:    "highlight",
				Content: fmt.Sprintf("📍 你来到了【%s】", scene.Name),
			})
		}
	}

	targetSceneID := scene.ID
	for _, spawn := range output.NewNPCs {
		npc, created, err := ensureNpc(ctx, st, targetSceneID, spawn)
		if err != nil {
			return extras, err
		}
		if created {
			*npcs = append(*npcs, npc)
			flags.NpcActivity[npc.Name] = "刚刚出现在此地的陌生人"
			extras = append(extras, NarrativeLine{
				Type:    "hint",
				Content: fmt.Sprintf("👤 你注意到 %s 出现在附近。", npc.Name),
			})
		}
	}

	for _, item := range output.NewItems {
		name := strings.TrimSpace(item.Name)
		if name == "" {
			continue
		}
		desc := strings.TrimSpace(item.Description)
		if _, ok, err := st.FindWorldItemByName(ctx, sess.ID, scene.ID, name, item.PickedUp); err != nil {
			return extras, err
		} else if ok {
			continue
		}
		row := model.GameWorldItem{
			SessionID:   sess.ID,
			Name:        name,
			Description: desc,
			IsTakeable:  item.Takeable,
			InInventory: item.PickedUp,
		}
		if item.PickedUp {
			row.SceneID = 0
		} else {
			row.SceneID = targetSceneID
		}
		if err := st.CreateWorldItem(ctx, &row); err != nil {
			return extras, err
		}
		flags.Inventory = appendUnique(flags.Inventory, name)
		if item.PickedUp {
			extras = append(extras, NarrativeLine{
				Type:    "hint",
				Content: fmt.Sprintf("🎒 你获得了：%s", name),
			})
		} else if desc != "" {
			flags.Discovered = appendUnique(flags.Discovered, name)
		}
	}

	if output.RandomEvent != nil {
		text := strings.TrimSpace(output.RandomEvent.Description)
		if text != "" {
			extras = append(extras, NarrativeLine{
				Type:    "event",
				Content: "⚡ " + text,
			})
			flags.PendingEvents = appendUnique(flags.PendingEvents, text)
		}
	}

	flags.TurnCount++
	return extras, nil
}

func applyNewScene(
	ctx context.Context,
	st Store,
	sess *model.GameSession,
	scene *model.GameScene,
	npcs *[]model.GameNpc,
	flags *WorldFlags,
	gen turnLLMScene,
) (bool, error) {
	name := strings.TrimSpace(gen.Name)
	if name == "" {
		return false, nil
	}

	existing, ok, err := st.FindSceneByName(ctx, name)
	if err != nil {
		return false, err
	}
	if ok {
		if gen.MovePlayer {
			*scene = existing
			sess.SceneID = existing.ID
			rows, err := st.ListNpcsByScene(ctx, existing.ID)
			if err != nil {
				return false, err
			}
			*npcs = rows
			flags.VisitedScenes = appendUnique(flags.VisitedScenes, name)
			return true, nil
		}
		return false, nil
	}

	desc := strings.TrimSpace(gen.Description)
	if desc == "" {
		desc = fmt.Sprintf("一片名为【%s】的区域，细节尚待探索。", name)
	}
	exits := gen.Exits
	if len(exits) == 0 {
		exits = []string{fmt.Sprintf("返回%s", scene.Name)}
	}
	exitsJSON, _ := json.Marshal(exits)
	newScene := &model.GameScene{
		Name:        name,
		Description: desc,
		ExitsJSON:   string(exitsJSON),
		IsSeed:      false,
	}
	if err := st.CreateScene(ctx, newScene); err != nil {
		return false, err
	}

	*scene = *newScene
	sess.SceneID = newScene.ID
	*npcs = nil
	flags.VisitedScenes = appendUnique(flags.VisitedScenes, name)
	if gen.SceneType != "" {
		flags.Discovered = appendUnique(flags.Discovered, gen.SceneType)
	}
	return true, nil
}

func ensureNpc(ctx context.Context, st Store, sceneID uint, spawn turnLLMNpcSpawn) (model.GameNpc, bool, error) {
	name := strings.TrimSpace(spawn.Name)
	if name == "" {
		return model.GameNpc{}, false, nil
	}
	existing, err := st.ListNpcsByScene(ctx, sceneID)
	if err != nil {
		return model.GameNpc{}, false, err
	}
	for _, npc := range existing {
		if npc.Name == name {
			return npc, false, nil
		}
	}
	persona := strings.TrimSpace(spawn.Persona)
	if persona == "" {
		persona = strings.TrimSpace(spawn.Role)
	}
	if persona == "" {
		persona = "神秘的存在，似乎与这片区域有关。"
	}
	row := model.GameNpc{
		SceneID:          sceneID,
		Name:             name,
		Persona:          persona,
		BaseFavorability: 50,
	}
	if err := st.CreateNpc(ctx, &row); err != nil {
		return model.GameNpc{}, false, err
	}
	return row, true, nil
}

func itemViewsFromModels(items []model.GameWorldItem) []ItemView {
	out := make([]ItemView, 0, len(items))
	for _, item := range items {
		out = append(out, ItemView{
			ID:          item.ID,
			Name:        item.Name,
			Description: item.Description,
			InInventory: item.InInventory,
		})
	}
	return out
}

func inventoryBlock(flags WorldFlags, items []model.GameWorldItem) string {
	if len(items) > 0 {
		var b strings.Builder
		b.WriteString("【背包】")
		for i, item := range items {
			if i > 0 {
				b.WriteString("、")
			}
			b.WriteString(item.Name)
		}
		b.WriteString("\n")
		return b.String()
	}
	if len(flags.Inventory) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【背包】")
	for i, item := range flags.Inventory {
		if i > 0 {
			b.WriteString("、")
		}
		b.WriteString(item)
	}
	b.WriteString("\n")
	return b.String()
}

func sceneItemsBlock(items []model.GameWorldItem) string {
	if len(items) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("【场景物品】")
	for i, item := range items {
		if i > 0 {
			b.WriteString("、")
		}
		b.WriteString(item.Name)
	}
	b.WriteString("\n")
	return b.String()
}
