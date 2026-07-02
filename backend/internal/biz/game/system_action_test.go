package gamebiz

import (
	"testing"

	"backend/model"
)

func TestNarrateInventoryCheck(t *testing.T) {
	snap := &SessionSnapshot{Inventory: nil, Flags: defaultWorldFlags()}
	state := TurnState{Scene: model.GameScene{Name: "迷雾小镇"}, Flags: snap.Flags}
	out, src, err := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdInspectInventory, Raw: "检查背包"}, state, nil)
	if err != nil || src != "system" {
		t.Fatalf("narrate inventory: src=%s err=%v", src, err)
	}
	if out.Prose == "" || contains(out.Prose, "缓慢移动") {
		t.Fatalf("unexpected prose: %s", out.Prose)
	}
}

func TestNarrateEnvironmentCheck(t *testing.T) {
	scene := model.GameScene{
		Name:        "迷雾小镇",
		Description: "晨雾笼罩的古老广场。",
		ExitsJSON:   `["旅人酒馆","森林小径"]`,
	}
	npcs := []model.GameNpc{{Name: "老人", Persona: "坐在长椅上"}}
	snap := &SessionSnapshot{
		Scene:  scene,
		NPCs:   npcs,
		Flags:  defaultWorldFlags(),
		Favor:  map[string]int{},
	}
	state := TurnState{Scene: scene, NPCs: npcs, Flags: snap.Flags}
	out, _, err := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdInspectScene, Raw: "检查环境"}, state, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !containsAll(out.Prose, "迷雾小镇", "老人", "旅人酒馆") {
		t.Fatalf("missing scene details: %s", out.Prose)
	}
}

func TestNarrateExploreWorld(t *testing.T) {
	scene := model.GameScene{Name: "迷雾小镇", ExitsJSON: `["东边","西边"]`}
	snap := &SessionSnapshot{Scene: scene, Flags: defaultWorldFlags()}
	state := TurnState{Scene: scene, Flags: snap.Flags}
	out, _, err := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdExploreWorld, Raw: "探索世界"}, state, nil)
	if err != nil {
		t.Fatal(err)
	}
	if contains(out.Prose, "缓慢移动") {
		t.Fatalf("should not use generic move prose: %s", out.Prose)
	}
}

func TestNarrateActionsDistinct(t *testing.T) {
	scene := model.GameScene{Name: "迷雾小镇", Description: "广场", ExitsJSON: `["酒馆"]`}
	flags := defaultWorldFlags()
	snap := &SessionSnapshot{Scene: scene, Flags: flags}
	state := TurnState{Scene: scene, Flags: flags}

	a, _, _ := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdInspectInventory}, state, nil)
	b, _, _ := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdInspectScene}, state, nil)
	c, _, _ := narrateTurn(t.Context(), nil, TurnDeps{}, snap, Command{Kind: CmdExploreWorld}, state, nil)
	if a.Prose == b.Prose || b.Prose == c.Prose || a.Prose == c.Prose {
		t.Fatalf("actions should produce distinct prose:\n1:%s\n2:%s\n3:%s", a.Prose, b.Prose, c.Prose)
	}
}
