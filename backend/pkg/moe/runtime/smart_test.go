package runtime

import (
	"testing"
	"time"
)

func TestDefaultSmartOptsDoesNotForceMinimumPostGap(t *testing.T) {
	if got := DefaultSmartOpts().MinIntervalHours; got != 0 {
		t.Fatalf("MinIntervalHours = %d, want 0", got)
	}
}

func TestSmartIntervalReasonOnlyAppliesWhenConfigured(t *testing.T) {
	now := time.Date(2026, time.September, 23, 12, 0, 0, 0, time.UTC)
	lastRunAt := now.Add(-time.Minute)

	if got := smartIntervalReason(now, &lastRunAt, 0); got != "" {
		t.Fatalf("smartIntervalReason() = %q, want no implicit interval", got)
	}
	if got := smartIntervalReason(now, &lastRunAt, 2); got == "" {
		t.Fatal("smartIntervalReason() = empty, want configured interval enforced")
	}
}
