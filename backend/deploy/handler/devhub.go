package handler

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

// MountDevHub serves docs/dev (devtools.html + tools) and proxies RPC /debug/* to rpcDebugUpstream.
// Deploy API routes (/api/deploy/*) must be registered on mux before calling this.
func MountDevHub(mux *http.ServeMux, workspaceRoot, rpcDebugUpstream string) {
	devRoot := filepath.Join(workspaceRoot, "docs", "dev")
	opsHome := filepath.Join(devRoot, "tools", "deploy-ops.html")
	if st, err := os.Stat(opsHome); err != nil || st.IsDir() {
		log.Printf("Moe Ops hub skipped: %s not found", opsHome)
		return
	}

	if upstream := strings.TrimSpace(rpcDebugUpstream); upstream != "" {
		target, err := url.Parse(strings.TrimRight(upstream, "/"))
		if err != nil {
			log.Printf("rpc debug proxy skipped: %v", err)
		} else {
			proxy := httputil.NewSingleHostReverseProxy(target)
			proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
				log.Printf("rpc debug proxy %s: %v", r.URL.Path, err)
				http.Error(w, "RPC debug API 不可达。请先 make rpc-debug 或 go run ./rpc -debug", http.StatusBadGateway)
			}
			mux.Handle("/debug/", withStaticCORS(proxy))
			mux.Handle("/debug", withStaticCORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, "/debug/", http.StatusMovedPermanently)
			})))
			log.Printf("rpc debug proxy: /debug/* -> %s", target.String())
		}
	}

	fileServer := http.FileServer(http.Dir(devRoot))
	indexPage := filepath.Join(workspaceRoot, "docs", "index.html")
	if st, err := os.Stat(indexPage); err == nil && !st.IsDir() {
		mux.HandleFunc("/index.html", func(w http.ResponseWriter, r *http.Request) {
			http.ServeFile(w, r, indexPage)
		})
	}
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			http.NotFound(w, r)
			return
		}
		if r.URL.Path == "/" || r.URL.Path == "" {
			http.ServeFile(w, r, opsHome)
			return
		}
		withStaticCORS(fileServer).ServeHTTP(w, r)
	})

	log.Printf("Moe Ops hub mounted (root=deploy-ops, docs/dev from %s)", devRoot)
}

func withStaticCORS(next http.Handler) http.Handler {
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
