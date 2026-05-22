package runner

import (
	"runtime"
	"strings"
)

var localPathExtra string

// InitLocalPathExtra sets optional PATH prefix from deploy config (see local_path_extra).
func InitLocalPathExtra(extra string) {
	localPathExtra = strings.TrimSpace(extra)
}

func appendLocalPathExtra(env []string) []string {
	extra := strings.TrimSpace(localPathExtra)
	if extra == "" {
		return env
	}
	sep := ":"
	if runtime.GOOS == "windows" {
		sep = ";"
	}
	path := envMapGet(env, "PATH")
	if path == "" {
		return append(env, "PATH="+extra)
	}
	return append(env, "PATH="+extra+sep+path)
}
