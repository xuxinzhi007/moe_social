package brain

import (
	"testing"

	"backend/model"
)

func TestEffectiveStabilityScoreDefault(t *testing.T) {
	rt := model.MoeAgentRuntime{}
	if got := EffectiveStabilityScore(rt); got != DefaultStabilityScore {
		t.Fatalf("expected %d, got %d", DefaultStabilityScore, got)
	}
}

func TestGenerationPolicyForStability(t *testing.T) {
	tests := []struct {
		score       int
		minQuality  int
		maxAttempts int
		relaxed     bool
	}{
		{score: 40, minQuality: 80, maxAttempts: 3, relaxed: false},
		{score: 55, minQuality: 70, maxAttempts: 4, relaxed: false},
		{score: 70, minQuality: 60, maxAttempts: 5, relaxed: true},
	}
	for _, tt := range tests {
		policy := GenerationPolicyForStability(tt.score)
		if policy.MinMemoryQuality != tt.minQuality || policy.MaxGenerateAttempts != tt.maxAttempts || policy.AllowRelaxedFallback != tt.relaxed {
			t.Fatalf("score=%d policy=%+v", tt.score, policy)
		}
	}
}

func TestSelectGenerationEpisodesUsesQualityGate(t *testing.T) {
	episodes := []model.MoeBotEpisode{
		{PostID: "low", QualityScore: 52},
		{PostID: "medium", QualityScore: 72},
		{PostID: "high", QualityScore: 88},
	}

	strict := SelectGenerationEpisodes(episodes, nil, GenerationPolicyForStability(45), 8)
	if len(strict) != 1 || strict[0].PostID != "high" {
		t.Fatalf("strict selection=%+v", strict)
	}

	normal := SelectGenerationEpisodes(episodes, nil, GenerationPolicyForStability(70), 8)
	if len(normal) != 2 || normal[0].PostID != "medium" || normal[1].PostID != "high" {
		t.Fatalf("normal selection=%+v", normal)
	}
}

func TestSelectGenerationEpisodesKeepsBestFallback(t *testing.T) {
	episodes := []model.MoeBotEpisode{
		{PostID: "better", QualityScore: 61},
		{PostID: "worse", QualityScore: 42},
	}
	selected := SelectGenerationEpisodes(episodes, nil, GenerationPolicyForStability(40), 8)
	if len(selected) != 1 || selected[0].PostID != "better" {
		t.Fatalf("selection=%+v", selected)
	}
}
