package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// MountDashboard serves deploy ops UI from docs/dev/tools/deploy-ops.html.
func MountDashboard(mux *http.ServeMux, workspaceRoot string) {
	dashboard := filepath.Join(workspaceRoot, "docs", "dev", "tools", "deploy-ops.html")
	if st, err := os.Stat(dashboard); err != nil || st.IsDir() {
		return
	}
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			http.NotFound(w, r)
			return
		}
		if r.URL.Path == "/" || r.URL.Path == "" || r.URL.Path == "/index.html" {
			http.ServeFile(w, r, dashboard)
			return
		}
		http.NotFound(w, r)
	})
}
