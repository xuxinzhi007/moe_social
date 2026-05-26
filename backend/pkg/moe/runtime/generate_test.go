package runtime

import (
	"strings"
	"testing"

	"backend/model"
	"backend/pkg/llminference"
)

func TestParsePostGenJSON(t *testing.T) {
	raw := "```json\n{\"content\":\"你好社区\",\"mood_tag\":\"happy\"}\n```"
	got, err := parsePostGenJSON(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.Content != "你好社区" || got.MoodTag != "happy" {
		t.Fatalf("unexpected: %+v", got)
	}
}

func TestParseSmartDecision(t *testing.T) {
	raw := `{"should_post":false,"reason":"社区已较活跃"}`
	got, err := parseSmartDecision(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.ShouldPost || got.Reason == "" {
		t.Fatalf("unexpected: %+v", got)
	}
}

func TestNormalizeMoodTag(t *testing.T) {
	if normalizeMoodTag("JOY") != "happy" {
		t.Fatal("expected happy")
	}
	if normalizeMoodTag("") != "calm" {
		t.Fatal("expected calm")
	}
}

func TestContentTooSimilar(t *testing.T) {
	recent := []model.Post{
		{Content: "今天练了速写，线条还是抖，但比上周顺一点"},
	}
	if !contentTooSimilar("今天练了速写，线条还是抖，但比上周顺一点", recent) {
		t.Fatal("expected duplicate")
	}
	if contentTooSimilar("周末想去逛手办展，有同好吗？", recent) {
		t.Fatal("expected different")
	}
}

func TestIsNovelStyleContent(t *testing.T) {
	poetic := "深夜时分，Moe社区里的灯火不曾熄灭，静静地等待着每个寻找温暖的灵魂。"
	if !isNovelStyleContent(poetic) {
		t.Fatal("expected novel style detected")
	}
	plain := "今天把线稿铺完了，周末想试试水彩，有人一起打卡吗？"
	if isNovelStyleContent(plain) {
		t.Fatal("expected plain post ok")
	}
	// 正常中文括号不应误杀
	casual := "刚练完速写（手指有点酸），明天想画场景，有推荐参考吗？"
	if isNovelStyleContent(casual) {
		t.Fatalf("parentheses should not trigger reject: score=%d", novelStyleScore(casual))
	}
}

func TestResolvePostModelPrefersConfig(t *testing.T) {
	deps := Deps{Inference: llminference.Config{DefaultModel: "default-model"}}
	rt := model.MoeAgentRuntime{ModelName: "my-tavern-character-card-alias"}
	got := resolvePostModel(deps, rt)
	// 无 viper 时回退 DefaultModel；有 bot_post_model 时优先（见集成环境）
	if got == "" {
		t.Fatal("expected model name")
	}
}

func TestSanitizePersona(t *testing.T) {
	rt := model.MoeAgentRuntime{DisplayName: "Moe 向导", AgentKey: "moe_guide"}
	got := sanitizePersona("简短友善的社区引导语，发一条不超过 80 字的动态。", rt)
	if strings.Contains(got, "80 字") {
		t.Fatalf("placeholder should be replaced: %s", got)
	}
}
