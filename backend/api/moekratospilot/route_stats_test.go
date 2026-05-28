package moekratospilot

import "testing"

func TestHTTPRouteCoverageAtLeast40(t *testing.T) {
	p := HTTPRouteCoveragePercent()
	if p < 40 {
		t.Fatalf("expected HTTP route coverage >= 40%%, got %d%% (%d/%d)",
			p, RegisteredKratosHTTPRoutes(), TotalGoZeroRoutes())
	}
}

func TestHTTPRouteCoverageAtLeast95(t *testing.T) {
	p := HTTPRouteCoveragePercent()
	if p < 95 {
		t.Fatalf("expected HTTP route coverage >= 95%%, got %d%% (%d/%d)",
			p, RegisteredKratosHTTPRoutes(), TotalGoZeroRoutes())
	}
}
