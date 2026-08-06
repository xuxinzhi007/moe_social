package apicomm

import "testing"

func TestParseHTTPByteRange(t *testing.T) {
	t.Parallel()

	start, end, err := ParseHTTPByteRange("bytes=0-99", 1000)
	if err != nil || start != 0 || end != 99 {
		t.Fatalf("unexpected range: %d-%d err=%v", start, end, err)
	}

	start, end, err = ParseHTTPByteRange("bytes=900-", 1000)
	if err != nil || start != 900 || end != 999 {
		t.Fatalf("open ended range: %d-%d err=%v", start, end, err)
	}
}
