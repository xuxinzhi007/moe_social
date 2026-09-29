package postdata

import (
	"testing"
	"time"
)

func TestHotRankSeedStableWithinWindow(t *testing.T) {
	start := time.Unix(1_700_000_000/600*600, 0).UTC()
	if hotRankSeed(start) != hotRankSeed(start.Add(hotRankWindow-time.Second)) {
		t.Fatal("seed changed inside the same window")
	}
	if hotRankSeed(start) == hotRankSeed(start.Add(hotRankWindow)) {
		t.Fatal("seed did not advance at the next window")
	}
}

func TestHotOrderSQLUsesSeed(t *testing.T) {
	sql := hotOrderSQL(42)
	if sql == hotOrderSQL(43) {
		t.Fatal("different seeds produced the same order clause")
	}
}
