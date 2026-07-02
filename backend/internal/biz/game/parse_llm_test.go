package gamebiz

import "testing"

func TestParseTurnLLMContentJSON(t *testing.T) {
	raw := `{
  "prose": "你穿过晨雾，走到长椅前。老人抬起头说：「你好，旅人。」",
  "game_time": "上午 10:30",
  "favor_deltas": {"老人": 2},
  "flags_patch": {"player_focus": "老人"}
}`
	out, ok := parseTurnLLMContent(raw)
	if !ok {
		t.Fatal("expected parsed json")
	}
	if !contains(out.Prose, "老人") {
		t.Fatalf("unexpected prose: %s", out.Prose)
	}
	if out.GameTime != "上午 10:30" {
		t.Fatalf("unexpected game time: %s", out.GameTime)
	}
	if out.FavorDeltas["老人"] != 2 {
		t.Fatalf("unexpected favor delta: %v", out.FavorDeltas)
	}
}

func TestParseTurnLLMContentRejectsTemplateProse(t *testing.T) {
	raw := `{
  "prose": "150-280字小说段落：含行动结果+环境变化+嵌入的NPC对话。",
  "game_time": "更新后的时间"
}`
	if _, ok := parseTurnLLMContent(raw); ok {
		t.Fatal("expected template prose to be rejected")
	}
}

func TestParseTurnLLMContentPlainProse(t *testing.T) {
	raw := "你停下脚步，晨雾在脚边流动。远处钟楼传来一声闷响，像是有人在上面移动。"
	out, ok := parseTurnLLMContent(raw)
	if !ok {
		t.Fatal("expected plain prose")
	}
	if out.Prose != raw {
		t.Fatalf("unexpected prose: %s", out.Prose)
	}
}

func TestParseTurnLLMContentJSONWithFence(t *testing.T) {
	raw := "```json\n{\"prose\":\"你推开门，暖气扑面而来。老板说：「欢迎。」\"}\n```"
	out, ok := parseTurnLLMContent(raw)
	if !ok || !contains(out.Prose, "欢迎") {
		t.Fatalf("expected fenced json prose, got ok=%v prose=%q", ok, out.Prose)
	}
}

func TestIsValidProseRejectsRawJSON(t *testing.T) {
	if isValidProse(`{"prose":"hello world from json"}`) {
		t.Fatal("expected raw json to be invalid prose")
	}
}
