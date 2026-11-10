package companionhttp

import (
	"context"
	"net"
	"net/http"
	"testing"
	"time"

	"strings"

	companionapp "backend/internal/service/companion"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func TestChatContextRouteIsRegistered(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	srv := khttp.NewServer(khttp.Listener(listener))
	RegisterChatStreamRoute(srv, &companionapp.AppService{})

	serveErr := make(chan error, 1)
	go func() {
		serveErr <- srv.Start(context.Background())
	}()
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = srv.Stop(stopCtx)
	})

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://" + listener.Addr().String() + "/api/companion/chat/context")
	if err != nil {
		t.Fatalf("GET context: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		t.Fatal("GET /api/companion/chat/context is not registered")
	}

	delResp, err := client.Do(func() *http.Request {
		req, reqErr := http.NewRequest(http.MethodDelete, "http://"+listener.Addr().String()+"/api/companion/chat/history", nil)
		if reqErr != nil {
			t.Fatalf("delete request: %v", reqErr)
		}
		return req
	}())
	if err != nil {
		t.Fatalf("DELETE history: %v", err)
	}
	defer delResp.Body.Close()
	if delResp.StatusCode == http.StatusNotFound {
		t.Fatal("DELETE /api/companion/chat/history is not registered")
	}

	postResp, err := client.Post("http://"+listener.Addr().String()+"/api/companion/chat/history/opening", "application/json", strings.NewReader(`{"text":"你好"}`))
	if err != nil {
		t.Fatalf("POST opening: %v", err)
	}
	defer postResp.Body.Close()
	if postResp.StatusCode == http.StatusNotFound {
		t.Fatal("POST /api/companion/chat/history/opening is not registered")
	}
	select {
	case err := <-serveErr:
		if err != nil && err != http.ErrServerClosed {
			t.Fatalf("server: %v", err)
		}
	default:
	}
}
