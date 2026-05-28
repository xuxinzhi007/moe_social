package runtime

import "testing"

func TestComputeStabilityDeltaFail(t *testing.T) {
	attempts := []GenAttemptRecord{
		{Outcome: GenOutcomeDuplicate},
		{Outcome: GenOutcomeDuplicate},
		{Outcome: GenOutcomeDuplicate},
		{Outcome: GenOutcomeDuplicate},
		{Outcome: GenOutcomeDuplicate},
	}
	delta, feedback := ComputeStabilityDelta(false, attempts, 0)
	if delta >= 0 {
		t.Fatalf("expected negative delta, got %d", delta)
	}
	if feedback == "" {
		t.Fatal("expected feedback")
	}
}

func TestComputeStabilityDeltaOK(t *testing.T) {
	attempts := []GenAttemptRecord{{Outcome: GenOutcomeOK}}
	delta, _ := ComputeStabilityDelta(true, attempts, 75)
	if delta <= 0 {
		t.Fatalf("expected positive delta, got %d", delta)
	}
}
