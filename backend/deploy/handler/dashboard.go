package handler

import (
	"os"
	"path/filepath"
)

// HasOpsConsole reports whether ops-console production build exists.
func HasOpsConsole(workspaceRoot string) bool {
	index := filepath.Join(workspaceRoot, "ops-console", "dist", "index.html")
	st, err := os.Stat(index)
	return err == nil && !st.IsDir()
}

// DashboardPath is the default Moe Ops UI path (React preferred when built).
func DashboardPath(workspaceRoot string) string {
	if HasOpsConsole(workspaceRoot) {
		return "/ops/"
	}
	return "/"
}
