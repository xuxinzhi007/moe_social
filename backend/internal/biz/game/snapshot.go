package gamebiz

import (
	"context"

	"backend/model"
	"backend/pkg/llminference"
)

// SessionSnapshot 单回合 SSOT：一次 Load，全程只读/在 Execute 阶段写回。
type SessionSnapshot struct {
	UserID       uint
	Session      model.GameSession
	Scene        model.GameScene
	NPCs         []model.GameNpc
	Flags        WorldFlags
	Favor        map[string]int
	Inventory    []model.GameWorldItem
	SceneItems   []model.GameWorldItem
	HistoryBlock string
	LlmOnline    bool
}

func loadSnapshot(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	userID uint,
	sessionID uint,
) (*SessionSnapshot, error) {
	sess, err := st.GetSession(ctx, userID, sessionID)
	if err != nil {
		return nil, err
	}
	scene, err := st.GetScene(ctx, sess.SceneID)
	if err != nil {
		return nil, err
	}
	npcs, err := st.ListNpcsByScene(ctx, sess.SceneID)
	if err != nil {
		return nil, err
	}
	flags := decodeWorldFlags(sess.FlagsJSON)
	// 双写架构：优先从新表读取，若不存在则从 flags_json 反序列化并回填
	if dbFlags := readWorldFlagsFromDB(ctx, st, sess.ID); dbFlags != nil {
		// 新表有数据：保留 StoryArcs 和 PendingEvents（这两个字段还未拆分到新表）
		dbFlags.StoryArcs = flags.StoryArcs
		dbFlags.PendingEvents = flags.PendingEvents
		dbFlags.Inventory = flags.Inventory
		dbFlags.VisitedScenes = flags.VisitedScenes
		flags = *dbFlags
	} else {
		// 新表无数据：回填（首次迁移）
		backfillWorldStateFromFlags(ctx, st, sess.ID, flags)
	}
	flags.TurnCount++
	ensureStoryArcsWithDB(ctx, st, &flags)

	inventory, _ := st.ListInventoryItems(ctx, sess.ID)
	sceneItems, _ := st.ListSceneItems(ctx, sess.ID, scene.ID)

	return &SessionSnapshot{
		UserID:       userID,
		Session:      sess,
		Scene:        scene,
		NPCs:         npcs,
		Flags:        flags,
		Favor:        decodeNpcFavor(sess.NpcFavorJSON),
		Inventory:    inventory,
		SceneItems:   sceneItems,
		HistoryBlock: buildRecentHistoryBlock(ctx, st, sess.ID),
		LlmOnline:    deps.Inference.Ready() && llminference.Ping(ctx, deps.Inference),
	}, nil
}

func (s *SessionSnapshot) npcViews() []NpcView {
	return npcViewsFromModels(s.NPCs, s.Favor)
}
