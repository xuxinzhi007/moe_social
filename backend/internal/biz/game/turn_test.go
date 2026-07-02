package gamebiz

import (
	"testing"

	"backend/model"
)

func TestFallbackTurnWalkToOldMan(t *testing.T) {
	scene := model.GameScene{Name: "迷雾小镇"}
	npcs := []NpcView{{ID: 1, Name: "老人", Favorability: 55}}
	flags := defaultWorldFlags()
	out := fallbackTurn("我走向老人", PlayerIntent{Type: "travel", Summary: "走向老人"}, scene, npcs, flags)
	if out.Prose == "" {
		t.Fatal("expected prose narrative")
	}
	if !containsAll(out.Prose, "晨雾", "老人") {
		t.Fatalf("prose missing expected content: %s", out.Prose)
	}
}

func TestFallbackTurnHelpBeggar(t *testing.T) {
	scene := model.GameScene{Name: "迷雾小镇"}
	npcs := []NpcView{{ID: 3, Name: "乞丐", Favorability: 45}}
	out := fallbackTurn("帮助乞丐", PlayerIntent{Type: "interact"}, scene, npcs, defaultWorldFlags())
	if out.FavorDeltas["乞丐"] != 5 {
		t.Fatalf("expected favor delta 5, got %d", out.FavorDeltas["乞丐"])
	}
	if len(out.NewMemories) == 0 {
		t.Fatal("expected memory for helping beggar")
	}
}

func TestFallbackTalkVsExplore(t *testing.T) {
	scene := model.GameScene{Name: "旅人酒馆"}
	npcs := []NpcView{{Name: "酒馆老板", Favorability: 50}}
	flags := defaultWorldFlags()

	talk := fallbackTurn("和附近的人说话", PlayerIntent{Type: "talk"}, scene, npcs, flags)
	travel := fallbackTurn("往一个方向探索", PlayerIntent{Type: "travel"}, scene, npcs, flags)
	if talk.Prose == travel.Prose {
		t.Fatalf("talk and travel fallback should differ: %q", talk.Prose)
	}
}

func TestNarrativeFromOutputProseFirst(t *testing.T) {
	lines := narrativeFromOutput(turnLLMOutput{
		Prose: "你穿过晨雾，走到长椅前。老人抬起头说：「你好。」",
	}, "我走向老人")
	if len(lines) < 2 {
		t.Fatalf("expected action_echo + prose, got %d", len(lines))
	}
	if lines[0].Type != "action_echo" {
		t.Fatalf("expected action_echo first")
	}
	if lines[1].Type != "prose" {
		t.Fatalf("expected prose second, got %s", lines[1].Type)
	}
}

func TestParseUserID(t *testing.T) {
	id, err := parseUserID("42")
	if err != nil || id != 42 {
		t.Fatalf("parseUserID failed: id=%d err=%v", id, err)
	}
	if _, err := parseUserID(""); err == nil {
	 t.Fatal("expected error for empty user id")
	}
}

func containsAll(s string, parts ...string) bool {
	for _, p := range parts {
		if !contains(s, p) {
			return false
		}
	}
	return true
}

func contains(s, sub string) bool {
	return len(sub) == 0 || (len(s) >= len(sub) && indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
