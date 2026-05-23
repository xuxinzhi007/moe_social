// RPC 监控控制台：独立进程，提供监控页并转发到 RPC 的 -debug 接口（类似 deploy-agent）。
package main

import (
	"backend/devports"
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

var (
	listen   = flag.String("listen", devports.AgentAddr, "dashboard listen address")
	upstream = flag.String("upstream", devports.RpcDebugUpstream(), "RPC -debug API base URL")
)

func main() {
	flag.Parse()

	root, err := findBackendRoot()
	if err != nil {
		log.Fatal(err)
	}
	toolsDir := filepath.Join(root, "..", "docs", "dev", "tools")
	if _, err := os.Stat(filepath.Join(toolsDir, "rpc-monitor.html")); err != nil {
		log.Fatalf("rpc-monitor.html not found under %s", toolsDir)
	}

	target, err := url.Parse(strings.TrimRight(*upstream, "/"))
	if err != nil {
		log.Fatalf("upstream: %v", err)
	}
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("proxy %s: %v", r.URL.Path, err)
		http.Error(w, "RPC debug API 不可达。请先 make rpc-debug 或 go run ./rpc -debug", http.StatusBadGateway)
	}

	mux := http.NewServeMux()
	mux.Handle("/debug/", withCORS(proxy))
	mux.Handle("/debug", withCORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/debug/", http.StatusMovedPermanently)
	})))
	mux.Handle("/", http.FileServer(http.Dir(toolsDir)))

	srv := &http.Server{Addr: *listen, Handler: mux}

	go func() {
		log.Printf("RPC monitor dashboard: http://%s/rpc-monitor.html", *listen)
		log.Printf("proxy upstream: %s (start RPC with: make rpc-debug)", target.String())
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	log.Print("shutting down rpc-monitor...")
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func findBackendRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if isBackendRoot(dir) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("backend root not found; run from backend/")
		}
		dir = parent
	}
}

func isBackendRoot(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, "go.mod")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "rpc", "super.go")); err != nil {
		return false
	}
	return true
}
