package vipbiz

import "testing"

func TestParsePlanID(t *testing.T) {
	if _, err := ParsePlanID(""); err != ErrInvalidArgument {
		t.Fatalf("empty id: got %v", err)
	}
	if _, err := ParsePlanID("abc"); err != ErrInvalidArgument {
		t.Fatalf("bad id: got %v", err)
	}
	id, err := ParsePlanID("42")
	if err != nil || id != 42 {
		t.Fatalf("want 42, got id=%d err=%v", id, err)
	}
}
