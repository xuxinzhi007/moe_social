package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/model"
)

// executePickup 拾取：先查场景物品，不存在则开放世界即时生成并入库。
func executePickup(
	ctx context.Context,
	st Store,
	snap *SessionSnapshot,
	state *TurnState,
	itemName string,
) (picked model.GameWorldItem, created bool, err error) {
	itemName = normalizePickupItemName(itemName)
	if itemName == "" {
		return model.GameWorldItem{}, false, nil
	}

	if row, ok, err := st.FindWorldItemByName(ctx, snap.Session.ID, state.Scene.ID, itemName, false); err != nil {
		return model.GameWorldItem{}, false, err
	} else if ok {
		if !row.IsTakeable {
			return row, false, nil
		}
		if err := st.MoveItemToInventory(ctx, row.ID); err != nil {
			return model.GameWorldItem{}, false, err
		}
		row.InInventory = true
		row.SceneID = 0
		state.Flags.Inventory = appendUnique(state.Flags.Inventory, itemName)
		state.Flags.PlayerFocus = itemName
		state.Flags.PlayerPosture = "拾取物品"
		return row, false, nil
	}

	desc := pickupItemDescription(itemName, state.Scene.Name)
	row := model.GameWorldItem{
		SessionID:   snap.Session.ID,
		Name:        itemName,
		Description: desc,
		IsTakeable:  true,
		InInventory: true,
		SceneID:     0,
	}
	if err := st.CreateWorldItem(ctx, &row); err != nil {
		return model.GameWorldItem{}, false, err
	}
	state.Flags.Inventory = appendUnique(state.Flags.Inventory, itemName)
	state.Flags.Discovered = appendUnique(state.Flags.Discovered, itemName)
	state.Flags.PlayerFocus = itemName
	state.Flags.PlayerPosture = "拾取物品"
	return row, true, nil
}

func normalizePickupItemName(name string) string {
	name = strings.TrimSpace(name)
	name = strings.Trim(name, "「」\"'")
	for _, suffix := range []string{"。", "，", "、"} {
		name = strings.TrimSuffix(name, suffix)
	}
	return strings.TrimSpace(name)
}

func pickupItemDescription(name, sceneName string) string {
	switch name {
	case "石头", "石子":
		return fmt.Sprintf("从%s随手捡起的一块普通石头，沉甸甸的。", sceneName)
	case "木棍":
		return "一根还算结实的木棍，或许能派上用场。"
	default:
		return fmt.Sprintf("你在%s拾到的%s。", sceneName, name)
	}
}

func pickupNarrateOutput(itemName string, item model.GameWorldItem, created bool) turnLLMOutput {
	name := normalizePickupItemName(itemName)
	if name == "" {
		return turnLLMOutput{
			Prose: "你弯下腰摸索了一阵，但没弄清楚想拿什么。可以说清楚一点，例如「捡起石头」。",
			SuggestedActions: []string{
				"观察周围",
				"检查背包",
				"和附近的人说话",
			},
		}
	}
	if item.Name != "" && !item.IsTakeable && !item.InInventory {
		return turnLLMOutput{
			Prose: fmt.Sprintf("你试图拿取%s，但它似乎固定在这里，拿不动。", name),
			SuggestedActions: []string{"观察周围", "检查环境", "和附近的人说话"},
		}
	}
	var prose string
	if created {
		prose = fmt.Sprintf("你弯腰从地上捡起%s，拍了拍灰，把它收进背包。", name)
	} else {
		prose = fmt.Sprintf("你将%s收入背包。", name)
	}
	desc := strings.TrimSpace(item.Description)
	if desc != "" && created {
		prose += desc
	}
	return turnLLMOutput{
		Prose: prose,
		SuggestedActions: []string{
			"检查背包",
			"观察周围",
			"和附近的人说话",
		},
	}
}

func isPickupAction(action string) bool {
	a := strings.TrimSpace(action)
	if a == "" {
		return false
	}
	for _, k := range []string{"捡", "拾", "拿取", "捡起", "拾起", "拿起", "拿到", "拣起"} {
		if strings.Contains(a, k) {
			return true
		}
	}
	return strings.Contains(a, "放进背包") || strings.Contains(a, "放入背包") ||
		strings.Contains(a, "收入背包") || strings.Contains(a, "装进背包")
}

func extractPickupItemName(action string) string {
	a := strings.TrimSpace(action)
	for _, prefix := range []string{"把", "将", "先", "然后"} {
		if strings.HasPrefix(a, prefix) {
			a = strings.TrimSpace(a[len(prefix):])
		}
	}
	for _, verb := range []string{"捡起", "拾起", "拾取", "拿取", "拿起", "拿到", "捡", "拾"} {
		if idx := strings.Index(a, verb); idx >= 0 {
			a = strings.TrimSpace(a[idx+len(verb):])
			break
		}
	}
	for _, suffix := range []string{
		"放进背包", "放入背包", "收入背包", "装进背包", "到背包", "入包", "起来", "并", "然后",
	} {
		if idx := strings.Index(a, suffix); idx > 0 {
			a = strings.TrimSpace(a[:idx])
			break
		}
	}
	a = normalizePickupItemName(a)
	if a != "" {
		return a
	}
	for _, item := range []string{"石头", "石子", "木棍", "钥匙", "硬币", "书信", "瓶子", "花朵", "叶子"} {
		if strings.Contains(action, item) {
			return item
		}
	}
	return ""
}
