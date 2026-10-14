package companionhttp

import (
	"context"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	companionapp "backend/internal/service/companion"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func TestHeroChatRouteIsRegistered(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	srv := khttp.NewServer(khttp.Listener(listener))
	RegisterHeroChatRoute(srv, &companionapp.AppService{})

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
	resp, err := client.Post(
		"http://"+listener.Addr().String()+"/api/companion/hero/chat",
		"application/json",
		strings.NewReader(`{"hero_slug":"xiaoxing","message":"你好"}`),
	)
	if err != nil {
		t.Fatalf("POST hero chat: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		t.Fatal("POST /api/companion/hero/chat is not registered")
	}
	select {
	case err := <-serveErr:
		if err != nil && err != http.ErrServerClosed {
			t.Fatalf("server: %v", err)
		}
	default:
	}
}
