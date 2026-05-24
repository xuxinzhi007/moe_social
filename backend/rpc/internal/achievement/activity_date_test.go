package achievement

import (
	"testing"
	"time"
)

func TestActivityStorageDateMatchesShanghaiCalendar(t *testing.T) {
	loc := activityLocation
	// 2026-05-24 10:51 CST
	now := time.Date(2026, 5, 24, 10, 51, 0, 0, loc)
	got := activityStorageDate(todayDate(now))
	if got.Year() != 2026 || got.Month() != time.May || got.Day() != 24 {
		t.Fatalf("storage date want 2026-05-24 UTC got %v", got)
	}
	if got.Location() != time.UTC {
		t.Fatalf("want UTC location got %v", got.Location())
	}
}

func TestShanghaiDayBounds(t *testing.T) {
	loc := activityLocation
	now := time.Date(2026, 5, 24, 10, 51, 0, 0, loc)
	start, end := ShanghaiDayBounds(now)
	if start.Day() != 24 || end.Day() != 25 {
		t.Fatalf("bounds start=%v end=%v", start, end)
	}
	if end.Sub(start) != 24*time.Hour {
		t.Fatalf("want 24h window got %v", end.Sub(start))
	}
}

func TestDailyActivityLookupDatesIncludesLegacyOffset(t *testing.T) {
	loc := activityLocation
	day := time.Date(2026, 5, 24, 0, 0, 0, 0, loc)
	dates := dailyActivityLookupDates(day)
	if len(dates) != 2 {
		t.Fatalf("want 2 candidates got %d", len(dates))
	}
	if dates[0].Day() != 24 || dates[1].Day() != 23 {
		t.Fatalf("candidates %v %v", dates[0], dates[1])
	}
}
