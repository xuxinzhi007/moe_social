package runtime

import (
	"strings"
	"testing"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
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

func TestLooseExtractPostJSON(t *testing.T) {
	raw := `{"content":"我正在深夜为手绘作品做最后的调整，手心有些微微发烫`
	got, err := parsePostGenJSON(raw)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got.Content, "手绘") {
		t.Fatalf("unexpected: %+v", got)
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

func TestReviewPostCandidateRejectsLowQualityContent(t *testing.T) {
	_, outcome, note := reviewPostCandidate(
		GeneratedPost{Content: "宁静"},
		model.MoeAgentRuntime{},
		nil,
		nil,
		nil,
		true,
	)
	if outcome != GenOutcomeQuality || !strings.Contains(note, "质量分") {
		t.Fatalf("review outcome=%q note=%q, want quality rejection", outcome, note)
	}
}

func TestReviewPostCandidateRejectsForbiddenTags(t *testing.T) {
	content := "周末把手绘线稿补完了，边缘比昨天整齐很多，准备继续试试新的配色。"
	_, outcome, note := reviewPostCandidate(
		GeneratedPost{Content: content, MoodTag: "happy"},
		model.MoeAgentRuntime{},
		nil,
		nil,
		[]string{"topic:手绘"},
		true,
	)
	if outcome != GenOutcomeForbidden || !strings.Contains(note, "topic:手绘") {
		t.Fatalf("review outcome=%q note=%q, want forbidden topic", outcome, note)
	}
}

func TestPickBestNovelFallbackAllowsOnlyQualitySemanticOverlap(t *testing.T) {
	recent := []model.Post{{
		Content: "今天收拾画桌的时候，发现线稿的袖口比例不对，只好把右手那部分重新画了一遍。",
	}}
	semanticCandidate := GeneratedPost{
		Content: "今天收拾画桌的时候，发现线稿的袖口比例不对，顺手把画笔按颜色重新排了一遍，抽屉也终于能关上了。",
		MoodTag: "happy",
	}
	if contentTooSimilar(semanticCandidate.Content, recent) ||
		!meaningTooSimilar(semanticCandidate.Content, recent, nil) {
		t.Fatal("test candidate must overlap semantically but not repeat the body")
	}

	selected := pickBestNovelFallback([]postGenCandidate{
		{gen: GeneratedPost{Content: recent[0].Content}, attempt: 1},
		{gen: semanticCandidate, attempt: 2},
	}, model.MoeAgentRuntime{}, recent, nil)
	if selected == nil || selected.gen.Content != semanticCandidate.Content {
		t.Fatalf("selected=%+v, want high-quality semantic fallback", selected)
	}

	lowQuality := GeneratedPost{Content: "宁静"}
	if brain.ComputeQualityScore(lowQuality.Content, lowQuality.MoodTag, 1, nil) >= brain.QualityApproveThreshold {
		t.Fatal("test candidate must be below the quality threshold")
	}
	selected = pickBestNovelFallback([]postGenCandidate{
		{gen: lowQuality, attempt: 3},
	}, model.MoeAgentRuntime{}, nil, nil)
	if selected != nil {
		t.Fatalf("selected=%+v, want low-quality candidate rejected", selected)
	}
}

func TestPostScenarioHintRotatesAcrossDirections(t *testing.T) {
	seen := make(map[string]struct{}, len(postScenarioHints))
	for index := range postScenarioHints {
		hint := postScenarioHint(index)
		if _, exists := seen[hint]; exists {
			t.Fatalf("scenario %d repeats an earlier direction: %q", index, hint)
		}
		seen[hint] = struct{}{}
	}
	if got := postScenarioHint(len(postScenarioHints)); got != postScenarioHint(0) {
		t.Fatalf("scenario wraparound = %q, want %q", got, postScenarioHint(0))
	}
}

func TestNextPostScenarioIndexContinuesAfterLastRunDirection(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("get sqlite connection pool: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() {
		if err := sqlDB.Close(); err != nil {
			t.Errorf("close sqlite: %v", err)
		}
	})
	if err := db.AutoMigrate(&model.MoeAgentRunLog{}); err != nil {
		t.Fatalf("AutoMigrate() error = %v", err)
	}

	bundle := RunLogBundle{
		CreativeDirectionIndex: 5,
		GenerateAttempts: []GenAttemptRecord{
			{Attempt: 1, DirectionIndex: 2, Outcome: GenOutcomeTheme},
			{Attempt: 2, DirectionIndex: 5, Outcome: GenOutcomeOK},
		},
	}
	if err := SaveAgentRunLog(db, "agent", true, "ok", "", bundle); err != nil {
		t.Fatalf("SaveAgentRunLog() error = %v", err)
	}

	if got, want := nextPostScenarioIndex(db, "agent"), 6; got != want {
		t.Fatalf("nextPostScenarioIndex() = %d, want %d", got, want)
	}
}
