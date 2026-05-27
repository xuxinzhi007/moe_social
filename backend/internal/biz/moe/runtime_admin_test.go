package moebiz

import "testing"

func TestParseBotUserID_Invalid(t *testing.T) {
	if _, err := ParseBotUserID(""); err == nil {
		t.Fatal("expected error for empty")
	}
	if _, err := ParseBotUserID("abc"); err == nil {
		t.Fatal("expected error for non-numeric")
	}
}

func TestParseBotUserID_OK(t *testing.T) {
	id, err := ParseBotUserID("42")
	if err != nil || id != 42 {
		t.Fatalf("id=%d err=%v", id, err)
	}
}
