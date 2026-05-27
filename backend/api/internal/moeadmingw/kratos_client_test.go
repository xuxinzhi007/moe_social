package moeadmingw

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"backend/api/internal/types"
)

func TestKratosHTTPClient_ListRuntimes(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/admin/moe/runtimes" {
			t.Fatalf("path %s", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(types.AdminListMoeRuntimesResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.AdminListMoeRuntimesData{
				Items: []types.MoeAgentRuntimeItem{
					{AgentKey: "bot-a", BotUserId: "1", Enabled: true},
				},
			},
		})
	}))
	defer srv.Close()

	c := NewKratosHTTPClient(srv.URL)
	rows, err := c.ListRuntimes(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0].AgentKey != "bot-a" {
		t.Fatalf("rows=%+v", rows)
	}
}

func TestGatewayRouteKratosHTTP(t *testing.T) {
	c := NewKratosHTTPClient("http://127.0.0.1:19032")
	gw := New(nil, nil, nil, c)
	if gw.Route() != "kratos_http" {
		t.Fatalf("route=%s", gw.Route())
	}
}
