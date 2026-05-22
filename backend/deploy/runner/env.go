package runner

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// BuildProcessEnv merges OS env with login-shell env (macOS/Linux) for Flutter/Go tools.
func BuildProcessEnv(workDir string) []string {
	base := os.Environ()
	if runtime.GOOS == "windows" {
		return base
	}
	login := captureLoginShellEnv()
	if len(login) == 0 {
		return ensureAndroidSDK(base)
	}
	merged := mergeEnv(base, login)
	return ensureAndroidSDK(merged)
}

func captureLoginShellEnv() map[string]string {
	ctx := context.Background()
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.CommandContext(ctx, "/bin/zsh", "-l", "-c", "env")
	default:
		cmd = exec.CommandContext(ctx, "/bin/bash", "-l", "-c", "env")
	}
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	env := make(map[string]string)
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok || k == "" {
			continue
		}
		env[k] = v
	}
	return env
}

func mergeEnv(base []string, extra map[string]string) []string {
	m := make(map[string]string)
	for _, e := range base {
		k, v, ok := strings.Cut(e, "=")
		if ok {
			m[k] = v
		}
	}
	for k, v := range extra {
		m[k] = v
	}
	out := make([]string, 0, len(m))
	for k, v := range m {
		out = append(out, k+"="+v)
	}
	return out
}

func ensureAndroidSDK(env []string) []string {
	if hasEnvKey(env, "ANDROID_HOME") || hasEnvKey(env, "ANDROID_SDK_ROOT") {
		return env
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return env
	}
	candidates := []string{
		filepath.Join(home, "sdk", "Android"),
		filepath.Join(home, "Library", "Android", "sdk"),
	}
	for _, dir := range candidates {
		if st, err := os.Stat(dir); err == nil && st.IsDir() {
			env = append(env, "ANDROID_HOME="+dir, "ANDROID_SDK_ROOT="+dir)
			break
		}
	}
	return env
}

func hasEnvKey(env []string, key string) bool {
	prefix := key + "="
	for _, e := range env {
		if strings.HasPrefix(e, prefix) {
			v := strings.TrimPrefix(e, prefix)
			return strings.TrimSpace(v) != ""
		}
	}
	return false
}

// shellQuote wraps a path for sh -c (shared with remote).
func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'"
}

// flutterShellCommand runs flutter in workspace via login shell.
func flutterShellCommand(workspace, flutterLine string) CommandSpec {
	ws := shellQuote(workspace)
	return CommandSpec{
		Dir:       workspace,
		Label:     flutterLine,
		Shell:     true,
		ShellLine: fmt.Sprintf("cd %s && %s", ws, flutterLine),
	}
}

// whichFlutter returns flutter binary path from login shell.
func whichFlutter(ctx context.Context) string {
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		cmd = exec.CommandContext(ctx, "/bin/zsh", "-l", "-c", "which flutter")
	} else if runtime.GOOS == "windows" {
		return "flutter"
	} else {
		cmd = exec.CommandContext(ctx, "/bin/bash", "-l", "-c", "which flutter")
	}
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// FlutterDoctor runs flutter doctor -v in workspace.
func (p *Platform) FlutterDoctor() CommandSpec {
	return flutterShellCommand(p.workspace, "flutter doctor -v")
}
