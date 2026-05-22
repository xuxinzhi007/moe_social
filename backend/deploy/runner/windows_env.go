package runner

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// sanitizeWindowsTempEnv fixes Git Bash TMPDIR=/tmp or C:\tmp when the directory does not exist.
// Windows go build fails with: creating work dir: GetFileAttributesEx C:\tmp: ...
func sanitizeWindowsTempEnv(env []string) []string {
	if runtime.GOOS != "windows" {
		return env
	}
	fallback := os.TempDir()
	if fallback == "" {
		if home, e := os.UserHomeDir(); e == nil {
			fallback = filepath.Join(home, "AppData", "Local", "Temp")
		}
	}
	if fallback != "" {
		_ = os.MkdirAll(fallback, 0o755)
	}

	m := envSliceToMap(env)
	for _, key := range []string{"TMPDIR", "TEMP", "TMP", "GOTMPDIR"} {
		v := strings.TrimSpace(m[key])
		if tempPathInvalid(v) {
			m[key] = fallback
		}
	}
	if strings.TrimSpace(m["TMPDIR"]) == "" {
		m["TMPDIR"] = fallback
	}
	if strings.TrimSpace(m["TEMP"]) == "" {
		m["TEMP"] = fallback
	}
	if strings.TrimSpace(m["TMP"]) == "" {
		m["TMP"] = fallback
	}
	return envMapToSlice(m)
}

func tempPathInvalid(p string) bool {
	p = strings.TrimSpace(p)
	if p == "" {
		return true
	}
	lower := strings.ToLower(filepath.Clean(p))
	if lower == `c:\tmp` || p == "/tmp" || p == `\tmp` {
		if _, err := os.Stat(p); err != nil {
			return true
		}
	}
	info, err := os.Stat(p)
	return err != nil || !info.IsDir()
}

func envSliceToMap(env []string) map[string]string {
	m := make(map[string]string, len(env))
	for _, e := range env {
		k, v, ok := strings.Cut(e, "=")
		if ok {
			m[k] = v
		}
	}
	return m
}

func envMapToSlice(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k, v := range m {
		out = append(out, k+"="+v)
	}
	return out
}
