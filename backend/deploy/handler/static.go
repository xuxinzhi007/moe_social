package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// MountDashboard serves web/deploy UI from workspace.
func MountDashboard(mux *http.ServeMux, workspaceRoot string) {
	webDir := filepath.Join(workspaceRoot, "web", "deploy")
	if st, err := os.Stat(webDir); err != nil || !st.IsDir() {
		return
	}
	fs := http.FileServer(http.Dir(webDir))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			http.NotFound(w, r)
			return
		}
		if r.URL.Path == "/" || r.URL.Path == "" {
			http.ServeFile(w, r, filepath.Join(webDir, "index.html"))
			return
		}
		fs.ServeHTTP(w, r)
	})
}
