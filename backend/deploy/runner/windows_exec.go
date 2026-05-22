package runner

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func wrapWindowsCmd(line string) string {
	// UTF-8 代码页，减少日志乱码；Agent 侧再用 GBK 解码兜底。
	return "chcp 65001 >nul & " + line
}

func windowsPathQuote(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return `""`
	}
	return `"` + strings.ReplaceAll(path, `"`, `\"`) + `"`
}

func captureWindowsEnv() map[string]string {
	if runtime.GOOS != "windows" {
		return nil
	}
	ctx := context.Background()
	script := `[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8; Get-ChildItem Env: | ForEach-Object { $_.Name + '=' + $_.Value }`
	cmd := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script)
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

func ensureWindowsFlutterPath(env []string) []string {
	if hasEnvKey(env, "FLUTTER_ROOT") {
		return env
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return env
	}
	// 常见 Flutter SDK 安装位置（用户可自行配置 PATH）
	candidates := []string{
		filepath.Join(home, "flutter", "bin"),
		filepath.Join(home, "dev", "flutter", "bin"),
		filepath.Join(home, "sdk", "flutter", "bin"),
	}
	for _, dir := range candidates {
		if st, err := os.Stat(filepath.Join(dir, "flutter.bat")); err == nil && !st.IsDir() {
			path := envMapGet(env, "PATH")
			if !strings.Contains(strings.ToLower(path), strings.ToLower(dir)) {
				env = append(env, "PATH="+dir+";"+path)
			}
			break
		}
	}
	return ensureAndroidSDK(env)
}

func envMapGet(env []string, key string) string {
	prefix := key + "="
	for _, e := range env {
		if strings.HasPrefix(e, prefix) {
			return strings.TrimPrefix(e, prefix)
		}
	}
	return ""
}

func whichFlutterWindows(ctx context.Context) string {
	script := `(Get-Command flutter -ErrorAction SilentlyContinue).Source`
	cmd := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}
