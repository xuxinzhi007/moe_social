package admingw

import (
	"testing"
)

func TestGatewayRouteKratosHTTP(t *testing.T) {
	c := NewKratosHTTPClient("http://127.0.0.1:19032")
	gw := New(nil, nil, c)
	if gw.Route() != "kratos_http" {
		t.Fatalf("route=%s", gw.Route())
	}
}
