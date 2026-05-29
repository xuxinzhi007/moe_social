package vipadmingw

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"backend/internal/legacy/types"
	vipbiz "backend/internal/biz/vip"
)

func TestKratosHTTPClient_ListPlans(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/admin/vip/plans" {
			t.Fatalf("path %s", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(types.AdminListVipPlansResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.AdminListVipPlansData{
				Items: []types.VipPlan{{Id: "1", Name: "pro"}},
				Total: 1,
			},
		})
	}))
	defer srv.Close()

	c := NewKratosHTTPClient(srv.URL)
	rows, total, err := c.ListPlans(context.Background(), vipbiz.ListPlansFilter{Page: 1})
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(rows) != 1 || rows[0].Name != "pro" {
		t.Fatalf("rows=%+v total=%d", rows, total)
	}
}

func TestGatewayRouteKratosHTTP(t *testing.T) {
	c := NewKratosHTTPClient("http://127.0.0.1:19032")
	gw := New(nil, nil, c)
	if gw.Route() != "kratos_http" {
		t.Fatalf("route=%s", gw.Route())
	}
}
