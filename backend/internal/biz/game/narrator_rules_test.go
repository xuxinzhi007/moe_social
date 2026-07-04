package gamebiz

import (
	"strings"
	"testing"

	"backend/model"
)

func TestTryNarratorRuleOutputMeta(t *testing.T) {
	out, src, ok := tryNarratorRuleOutput(Command{Kind: CmdFreeform, Raw: "你是什么模型？"}, modelGameScene())
	if !ok || src != "go_meta" {
		t.Fatalf("expected go_meta, got ok=%v src=%s", ok, src)
	}
	if out.Prose == "" || strings.Contains(out.Prose, "模型，身穿") {
		t.Fatalf("unexpected prose: %s", out.Prose)
	}
}

func TestTryNarratorRuleOutputImpossible(t *testing.T) {
	out, src, ok := tryNarratorRuleOutput(Command{Kind: CmdFreeform, Raw: "去月球"}, modelGameScene())
	if !ok || src != "go_impossible" {
		t.Fatalf("expected go_impossible, got ok=%v src=%s", ok, src)
	}
	if !strings.Contains(out.Prose, "月球") || !strings.Contains(out.Prose, "拉回") {
		t.Fatalf("unexpected prose: %s", out.Prose)
	}
}

func TestParseObserveSurroundings(t *testing.T) {
	cmd := parseOfflineCommand("看看周围有什么", testSnap())
	if cmd.Kind != CmdInspectScene {
		t.Fatalf("expected CmdInspectScene, got %s", cmd.Kind)
	}
}

func modelGameScene() model.GameScene {
	return model.GameScene{
		Name:        "迷雾小镇广场",
		Description: "晨雾中的广场",
		ExitsJSON:   `["旅人酒馆","教堂","森林小径"]`,
	}
}

func testSnap() *SessionSnapshot {
	return &SessionSnapshot{Scene: modelGameScene()}
}
