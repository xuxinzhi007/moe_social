package adminbiz

import "testing"

func TestNormalizePlatform(t *testing.T) {
	if got := normalizePlatform(""); got != "android" {
		t.Fatalf("empty -> android, got %q", got)
	}
	if got := normalizePlatform(" Android "); got != "android" {
		t.Fatalf("trim/lower, got %q", got)
	}
}

func TestValidateApkURL(t *testing.T) {
	if err := validateApkURL(""); err == nil {
		t.Fatal("empty should fail")
	}
	if err := validateApkURL("not-a-url"); err == nil {
		t.Fatal("invalid should fail")
	}
	if err := validateApkURL("https://github.com/x/y/releases/download/v1/a.apk"); err != nil {
		t.Fatalf("valid url: %v", err)
	}
}
