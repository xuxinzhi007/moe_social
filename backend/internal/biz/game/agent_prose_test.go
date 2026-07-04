package gamebiz

import "testing"

func TestAcceptAgentProseBlocksPromptLeak(t *testing.T) {
	_, ok := acceptAgentProse("若本步无需再调工具，在此输出叙事；否则留空")
	if ok {
		t.Fatal("should block prompt leakage")
	}
}

func TestAcceptAgentProseAllowsNarrative(t *testing.T) {
	prose, ok := acceptAgentProse("你蹲下身，指尖触到冰凉的石面——老人在不远处抬眼，烟斗里的火星明明灭灭。")
	if !ok || prose == "" {
		t.Fatal("should accept valid narrative")
	}
}

func TestDedupeNarrativeLines(t *testing.T) {
	lines := dedupeNarrativeLines([]NarrativeLine{
		{Type: "event", Content: "🌍 迷雾小镇：老人似乎注意到了什么异常"},
		{Type: "event", Content: "🌍 迷雾小镇：老人似乎注意到了什么异常"},
		{Type: "action_echo", Content: "观察周围"},
	})
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines after dedupe, got %d", len(lines))
	}
}
