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
