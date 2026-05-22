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

// windowsShellState holds resolved local shell on Windows (set once at Registry init).
var windowsShellState struct {
	mode    string // cmd | git-bash
	bashExe string
}

// InitWindowsShell configures how local jobs run on Windows (from deploy config).
func InitWindowsShell(mode, bashExe string) {
	windowsShellState.mode = strings.TrimSpace(mode)
	windowsShellState.bashExe = strings.TrimSpace(bashExe)
}

// WindowsShellInfo returns mode label for API/UI.
func WindowsShellInfo() (mode string, bashPath string, label string) {
	if runtime.GOOS != "windows" {
		return "", "", ""
	}
	mode = windowsShellState.mode
	if mode == "" {
		mode = "cmd"
	}
	bashPath = windowsShellState.bashExe
	switch mode {
	case "git-bash":
		label = "Git Bash"
		if bashPath != "" {
			label += " (" + bashPath + ")"
		}
	default:
		label = "cmd.exe"
	}
	return mode, bashPath, label
}

func useGitBashOnWindows() bool {
	return runtime.GOOS == "windows" &&
		windowsShellState.mode == "git-bash" &&
		windowsShellState.bashExe != "" &&
		fileExists(windowsShellState.bashExe)
}

func fileExists(path string) bool {
	st, err := os.Stat(path)
	return err == nil && !st.IsDir()
}

// FindGitBash locates bash.exe from Git for Windows install.
func FindGitBash() string {
	var candidates []string
	for _, key := range []string{"ProgramFiles", "ProgramFiles(x86)", "LocalAppData"} {
		if base := os.Getenv(key); base != "" {
			candidates = append(candidates, filepath.Join(base, "Git", "bin", "bash.exe"))
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		candidates = append(candidates,
			filepath.Join(home, "scoop", "apps", "git", "current", "bin", "bash.exe"),
			filepath.Join(home, "AppData", "Local", "Programs", "Git", "bin", "bash.exe"),
		)
	}
	for _, p := range candidates {
		if fileExists(p) {
			return p
		}
	}
	if p, err := exec.LookPath("bash.exe"); err == nil && fileExists(p) {
		return p
	}
	return ""
}

func runGitBashCapture(ctx context.Context, script string) string {
	if !useGitBashOnWindows() {
		return ""
	}
	cmd := exec.CommandContext(ctx, windowsShellState.bashExe, "-l", "-c", script)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func captureGitBashEnv() map[string]string {
	if !useGitBashOnWindows() {
		return nil
	}
	ctx := context.Background()
	cmd := exec.CommandContext(ctx, windowsShellState.bashExe, "-l", "-c", "env")
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

// windowsWorkspaceCD returns a cd prefix for the workspace in the active Windows shell.
func windowsWorkspaceCD(workspace string) string {
	if useGitBashOnWindows() {
		return fmt.Sprintf("cd %s && ", shellQuote(toGitBashPath(workspace)))
	}
	return fmt.Sprintf("cd /d %s & ", windowsPathQuote(workspace))
}

// toGitBashPath converts a Windows path to a form Git Bash accepts in scripts.
func toGitBashPath(p string) string {
	p = filepath.Clean(p)
	if len(p) >= 2 && p[1] == ':' {
		drive := strings.ToLower(string(p[0]))
		rest := strings.ReplaceAll(p[2:], "\\", "/")
		return "/" + drive + rest
	}
	return strings.ReplaceAll(p, "\\", "/")
}
