package devlauncher

import (
	"errors"
	"os"
	"path/filepath"
)

// FindBackendRoot walks up from cwd until api/super.go and rpc/super.go exist.
func FindBackendRoot() (string, error) {
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
			return "", errors.New("backend root not found (no go.mod with api/super.go); run from backend/ or repo root")
		}
		dir = parent
	}
}

func isBackendRoot(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, "go.mod")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "api", "super.go")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "rpc", "super.go")); err != nil {
		return false
	}
	return true
}
