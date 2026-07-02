package gamebiz

import (
	"context"
	"fmt"

	"backend/model"
)

func InitSession(ctx context.Context, st Store, userIDRaw string, forceNew bool) (SessionView, error) {
	if st == nil {
		return SessionView{}, fmt.Errorf("game store unavailable")
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return SessionView{}, err
	}
	st = st.WithContext(ctx)
	if err := EnsureSeedWorld(ctx, st); err != nil {
		return SessionView{}, err
	}

	if forceNew {
		if err := st.DeactivateSessions(ctx, userID); err != nil {
			return SessionView{}, err
		}
	} else if sess, ok, err := st.FindActiveSession(ctx, userID); err != nil {
		return SessionView{}, err
	} else if ok {
		view, err := buildSessionView(ctx, st, sess)
		if err != nil {
			return SessionView{}, err
		}
		history, _ := loadSessionHistory(ctx, st, sess.ID, 40)
		view.History = history
		if len(history) == 0 {
			view.Opening = []NarrativeLine{
				{Type: "prose", Content: fmt.Sprintf("你回到了【%s】。%s", view.Scene.Name, decodeWorldFlags(sess.FlagsJSON).WorldMood)},
			}
		}
		return view, nil
	}

	scene, ok, err := st.FindSeedSceneByName(ctx, seedSceneName)
	if err != nil {
		return SessionView{}, err
	}
	if !ok {
		return SessionView{}, fmt.Errorf("seed scene missing")
	}

	npcs, err := st.ListNpcsByScene(ctx, scene.ID)
	if err != nil {
		return SessionView{}, err
	}
	favor := map[string]int{}
	for _, npc := range npcs {
		favor[fmt.Sprintf("%d", npc.ID)] = npc.BaseFavorability
	}
	flags := defaultWorldFlags()

	sess := &model.GameSession{
		UserID:       userID,
		SceneID:      scene.ID,
		GameTime:     "上午 10:00",
		FlagsJSON:    encodeWorldFlags(flags),
		NpcFavorJSON: encodeNpcFavor(favor),
		IsActive:     true,
	}
	if err := st.CreateSession(ctx, sess); err != nil {
		return SessionView{}, err
	}

	view, err := buildSessionView(ctx, st, *sess)
	if err != nil {
		return SessionView{}, err
	}
	view.Opening = defaultOpening(scene.Name)
	return view, nil
}

func GetState(ctx context.Context, st Store, userIDRaw string, sessionID uint64) (SessionView, error) {
	if st == nil {
		return SessionView{}, fmt.Errorf("game store unavailable")
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return SessionView{}, err
	}
	st = st.WithContext(ctx)
	if sessionID == 0 {
		sess, ok, err := st.FindActiveSession(ctx, userID)
		if err != nil {
			return SessionView{}, err
		}
		if !ok {
			return SessionView{}, fmt.Errorf("no active session")
		}
		return buildSessionView(ctx, st, sess)
	}
	sess, err := st.GetSession(ctx, userID, uint(sessionID))
	if err != nil {
		return SessionView{}, err
	}
	return buildSessionView(ctx, st, sess)
}

func buildSessionView(ctx context.Context, st Store, sess model.GameSession) (SessionView, error) {
	scene, err := st.GetScene(ctx, sess.SceneID)
	if err != nil {
		return SessionView{}, err
	}
	npcs, err := st.ListNpcsByScene(ctx, sess.SceneID)
	if err != nil {
		return SessionView{}, err
	}
	favor := decodeNpcFavor(sess.NpcFavorJSON)
	flags := decodeWorldFlags(sess.FlagsJSON)
	views := npcViewsFromModels(npcs, favor)
	items, _ := st.ListInventoryItems(ctx, sess.ID)
	return SessionView{
		SessionID:           uint64(sess.ID),
		Scene:               sceneViewFromModel(scene),
		Npcs:                views,
		Inventory:           itemViewsFromModels(items),
		GameTime:            sess.GameTime,
		OverallFavorability: averageFavor(favor, views),
		FlagsJSON:           sess.FlagsJSON,
		PlayerFocus:         flags.PlayerFocus,
		VisitedScenes:       flags.VisitedScenes,
		StoryArcs:           flags.StoryArcs,
	}, nil
}
