package gamebiz

import (
	"testing"

	"backend/model"
)

func TestParseTravelTargetFromExitLabel(t *testing.T) {
	exits := []string{"东边：旅人酒馆", "北边：早市"}
	target, ok := parseTravelTarget("前往东边：旅人酒馆", exits)
	if !ok || target.Name != "旅人酒馆" {
		t.Fatalf("unexpected target: %+v ok=%v", target, ok)
	}
}

func TestParseTravelTargetSeaside(t *testing.T) {
	target, ok := parseTravelTarget("前往海边", nil)
	if !ok || target.Name != "海边码头" {
		t.Fatalf("unexpected seaside target: %+v", target)
	}
}

func TestDialogueContinuationNo(t *testing.T) {
	flags := defaultWorldFlags()
	flags.LastTalkNPC = "老人"
	flags.PlayerFocus = "老人"
	flags.InDialogue = true
	snap := &SessionSnapshot{
		Flags: flags,
		Scene: model.GameScene{Name: "迷雾小镇"},
		NPCs:  []model.GameNpc{{Name: "老人"}},
	}
	cmd := parseCommand("没有啊", snap)
	if cmd.Kind != CmdTalkReply {
		t.Fatalf("expected talk reply, got %s", cmd.Kind)
	}
	state := TurnState{Scene: snap.Scene, NPCs: snap.NPCs, Flags: flags}
	out, _, err := narrateTurn(t.Context(), nil, TurnDeps{}, snap, cmd, state, nil)
	if err != nil {
		t.Fatal(err)
	}
	if contains(out.Prose, "晨雾中的小镇广场") {
		t.Fatalf("should not repeat scene description: %s", out.Prose)
	}
}

func TestIsPureTravelAction(t *testing.T) {
	if !isPureTravelAction("前往北边：早市") {
		t.Fatal("expected travel action")
	}
	if isPureTravelAction("没有啊") {
		t.Fatal("short reply should not be travel")
	}
}
