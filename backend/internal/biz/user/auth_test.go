package userbiz

import "testing"

func TestIsTenDigitMoe(t *testing.T) {
	if !isTenDigitMoe("1234567890") {
		t.Fatal("expected true")
	}
	if isTenDigitMoe("123456789") {
		t.Fatal("expected false")
	}
}
