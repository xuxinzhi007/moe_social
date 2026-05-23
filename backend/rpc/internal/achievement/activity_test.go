package achievement

import "testing"

func TestCurrentEventHour(t *testing.T) {
	h := CurrentEventHour()
	if h < 0 || h > 23 {
		t.Fatalf("hour out of range: %d", h)
	}
}
