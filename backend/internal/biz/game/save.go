package gamebiz

import (
	"context"
	"encoding/json"
	"fmt"

	"backend/model"
)

// GameSaveSnapshot 存档快照：序列化完整会话状态。
type GameSaveSnapshot struct {
	Session      model.GameSession   `json:"session"`
	Flags        WorldFlags          `json:"flags"`
	Favor        map[string]int      `json:"favor"`
	Scene        model.GameScene     `json:"scene"`
	NPCs         []model.GameNpc     `json:"npcs"`
	Inventory    []model.GameWorldItem `json:"inventory"`
	SceneItems   []model.GameWorldItem `json:"scene_items"`
}

// SaveGame 保存游戏到指定槽位。
func SaveGame(ctx context.Context, st Store, userID uint, sessionID uint, slotIndex uint8, label string) error {
	if st == nil {
		return fmt.Errorf("game store unavailable")
	}
	st = st.WithContext(ctx)

	sess, err := st.GetSession(ctx, userID, sessionID)
	if err != nil {
		return fmt.Errorf("get session: %w", err)
	}
	scene, err := st.GetScene(ctx, sess.SceneID)
	if err != nil {
		return fmt.Errorf("get scene: %w", err)
	}
	npcs, err := st.ListNpcsByScene(ctx, sess.SceneID)
	if err != nil {
		return fmt.Errorf("list npcs: %w", err)
	}
	inventory, _ := st.ListInventoryItems(ctx, sess.ID)
	sceneItems, _ := st.ListSceneItems(ctx, sess.ID, scene.ID)
	flags := decodeWorldFlags(sess.FlagsJSON)
	favor := decodeNpcFavor(sess.NpcFavorJSON)

	snap := GameSaveSnapshot{
		Session:    sess,
		Flags:      flags,
		Favor:      favor,
		Scene:      scene,
		NPCs:       npcs,
		Inventory:  inventory,
		SceneItems: sceneItems,
	}
	snapJSON, err := json.Marshal(snap)
	if err != nil {
		return fmt.Errorf("marshal snapshot: %w", err)
	}

	if label == "" {
		label = fmt.Sprintf("槽位 %d - %s", slotIndex, scene.Name)
	}

	slot := &model.GameSaveSlot{
		UserID:       userID,
		SessionID:    sessionID,
		SlotIndex:    slotIndex,
		Label:        label,
		SnapshotJSON: string(snapJSON),
		TurnCount:    flags.TurnCount,
		SceneName:    scene.Name,
	}
	return st.SaveGame(ctx, slot)
}

// LoadGame 从槽位加载游戏，返回反序列化后的快照。
func LoadGame(ctx context.Context, st Store, userID uint, slotIndex uint8) (*GameSaveSnapshot, error) {
	if st == nil {
		return nil, fmt.Errorf("game store unavailable")
	}
	st = st.WithContext(ctx)

	slots, err := st.ListSaveSlots(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("list save slots: %w", err)
	}
	for _, slot := range slots {
		if slot.SlotIndex == slotIndex {
			var snap GameSaveSnapshot
			if err := json.Unmarshal([]byte(slot.SnapshotJSON), &snap); err != nil {
				return nil, fmt.Errorf("unmarshal snapshot: %w", err)
			}
			return &snap, nil
		}
	}
	return nil, fmt.Errorf("save slot %d not found", slotIndex)
}

// ListSaveSlots 列出用户所有存档。
func ListSaveSlots(ctx context.Context, st Store, userID uint) ([]model.GameSaveSlot, error) {
	if st == nil {
		return nil, fmt.Errorf("game store unavailable")
	}
	return st.WithContext(ctx).ListSaveSlots(ctx, userID)
}

// DeleteSaveSlot 删除指定存档槽位。
func DeleteSaveSlot(ctx context.Context, st Store, userID uint, slotIndex uint8) error {
	if st == nil {
		return fmt.Errorf("game store unavailable")
	}
	return st.WithContext(ctx).DeleteSaveSlot(ctx, userID, slotIndex)
}
