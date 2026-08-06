package routestats

import "testing"

func TestProtoHTTPRouteCountPositive(t *testing.T) {
	if ProtoHTTPRouteCount() <= 0 {
		t.Fatalf("expected proto HTTP routes > 0, got %d", ProtoHTTPRouteCount())
	}
}

func TestTotalHTTPRoutesIncludesTransport(t *testing.T) {
	total := TotalHTTPRoutes()
	wantMin := ProtoHTTPRouteCount() + SwaggerRouteCount + TransportHTTPRoutes
	if total != wantMin {
		t.Fatalf("TotalHTTPRoutes=%d want %d", total, wantMin)
	}
}
