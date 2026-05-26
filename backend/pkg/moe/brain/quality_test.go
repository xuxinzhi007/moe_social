package brain

import "testing"

func TestComputeQualityScore(t *testing.T) {
	forbidden := []string{"risk:诗意腔", "type:套路开场"}
	poetic := "周三的深夜，Moe社区的星光温柔，灵魂在共鸣"
	casual := "刚画完线稿，手酸，马克笔没水了，你们周末干嘛？"
	qPoetic := ComputeQualityScore(poetic, "calm", 4, forbidden)
	qCasual := ComputeQualityScore(casual, "happy", 0, forbidden)
	if qPoetic >= QualityApproveThreshold {
		t.Fatalf("poetic should score low, got %d", qPoetic)
	}
	if qCasual < QualityApproveThreshold {
		t.Fatalf("casual should score ok, got %d", qCasual)
	}
}

func TestNeedsRefinement(t *testing.T) {
	tags := []string{"risk:诗意腔", "type:提问"}
	if !NeedsRefinement(55, tags, []string{"risk:诗意腔"}) {
		t.Fatal("expected refinement needed")
	}
	if NeedsRefinement(85, []string{"tone:口语"}, nil) {
		t.Fatal("expected no refinement")
	}
}
