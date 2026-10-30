package runner

import (
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	deploycfg "backend/deploy/config"
)

// Allowed remote config paths (relative to backend_dir on VPS).
var allowedRemoteConfigPaths = map[string]bool{
	"docker-compose.binary.yml":    true,
	"docker-compose.yml":           true,
	"config.yaml":                  true,
	"config/config.yaml":           true,
	"config/moe-service-app.yaml":  true,
	"config/moe-service-data.yaml": true,
	"Modelfile":                    true,
}

// ValidateRemoteConfigName returns safe relative path for remote file ops.
func ValidateRemoteConfigName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", fmt.Errorf("缺少 file 参数")
	}
	name = strings.ReplaceAll(name, "\\", "/")
	if strings.Contains(name, "..") || strings.HasPrefix(name, "/") {
		return "", fmt.Errorf("非法文件路径")
	}
	if !allowedRemoteConfigPaths[name] {
		return "", fmt.Errorf("不允许编辑该文件，仅支持 Modelfile、compose 与 config 白名单")
	}
	return name, nil
}

// ReadRemoteConfig reads a whitelisted file from VPS backend_dir (or local backend_dir when target is local).
func ReadRemoteConfig(ctx context.Context, cfg *deploycfg.Config, targetID, fileName string) (content string, remotePath string, err error) {
	base, err := ValidateRemoteConfigName(fileName)
	if err != nil {
		return "", "", err
	}
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		localDir := strings.TrimSpace(cfg.BackendAbs())
		if localDir == "" {
			return "", "", fmt.Errorf("未配置本机 backend_dir")
		}
		localPath := filepath.Join(localDir, filepath.FromSlash(base))
		raw, readErr := os.ReadFile(localPath)
		if readErr != nil {
			if os.IsNotExist(readErr) {
				return "", localPath, fmt.Errorf("本机文件不存在: %s", localPath)
			}
			return "", localPath, fmt.Errorf("读取本机文件失败: %w", readErr)
		}
		return string(raw), localPath, nil
	}
	if strings.TrimSpace(t.BackendDir) == "" {
		return "", "", fmt.Errorf("未配置 backend_dir")
	}
	remotePath = joinRemotePath(t.BackendDir, base)
	rp := NewRemotePlatform(t)
	script := fmt.Sprintf(
		`if [ ! -f %s ]; then echo MOE_FILE_MISSING; exit 2; fi; echo MOE_FILE_BEGIN; cat %s; echo MOE_FILE_END`,
		shellQuote(remotePath), shellQuote(remotePath),
	)
	spec := CommandSpec{
		Label:     "read remote config",
		Shell:     true,
		ShellLine: script,
		SSH:       rp.sshConfig(),
	}
	out, code, err := RunCapture(ctx, spec)
	if err != nil {
		return "", remotePath, err
	}
	if code == 2 || strings.Contains(out, "MOE_FILE_MISSING") {
		return "", remotePath, fmt.Errorf("远程文件不存在: %s（先运行「云平台路径巡检」）", remotePath)
	}
	if code != 0 {
		return "", remotePath, fmt.Errorf("读取失败 exit=%d: %s", code, strings.TrimSpace(out))
	}
	content = extractBetweenMarkers(out, "MOE_FILE_BEGIN", "MOE_FILE_END")
	return content, remotePath, nil
}

// WriteRemoteConfig writes content with a timestamped backup on the VPS.
func WriteRemoteConfig(ctx context.Context, cfg *deploycfg.Config, targetID, fileName, content string) (remotePath, backupPath string, err error) {
	base, err := ValidateRemoteConfigName(fileName)
	if err != nil {
		return "", "", err
	}
	if len(content) > 512*1024 {
		return "", "", fmt.Errorf("文件过大（最大 512KB）")
	}
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		localDir := strings.TrimSpace(cfg.BackendAbs())
		if localDir == "" {
			return "", "", fmt.Errorf("未配置本机 backend_dir")
		}
		localPath := filepath.Join(localDir, filepath.FromSlash(base))
		if err := os.MkdirAll(filepath.Dir(localPath), 0o755); err != nil {
			return localPath, "", fmt.Errorf("创建目录失败: %w", err)
		}
		if prev, readErr := os.ReadFile(localPath); readErr == nil {
			backupPath = localPath + ".bak." + time.Now().Format("20060102-150405")
			_ = os.WriteFile(backupPath, prev, 0o644)
		}
		if err := os.WriteFile(localPath, []byte(content), 0o644); err != nil {
			return localPath, backupPath, fmt.Errorf("写入本机文件失败: %w", err)
		}
		return localPath, backupPath, nil
	}
	if strings.TrimSpace(t.BackendDir) == "" {
		return "", "", fmt.Errorf("未配置 backend_dir")
	}
	remotePath = joinRemotePath(t.BackendDir, base)
	backupPath = remotePath + ".bak." + time.Now().Format("20060102-150405")
	encoded := base64.StdEncoding.EncodeToString([]byte(content))
	rp := NewRemotePlatform(t)
	script := fmt.Sprintf(
		`set -e
if [ ! -d %s ]; then echo "backend_dir missing"; exit 3; fi
if [ -f %s ]; then cp %s %s; fi
echo %s | base64 -d > %s.tmp
mv %s.tmp %s
echo MOE_WRITE_OK`,
		shellQuote(t.BackendDir),
		shellQuote(remotePath), shellQuote(remotePath), shellQuote(backupPath),
		shellQuote(encoded),
		shellQuote(remotePath), shellQuote(remotePath), shellQuote(remotePath),
	)
	spec := CommandSpec{
		Label:     "write remote config",
		Shell:     true,
		ShellLine: script,
		SSH:       rp.sshConfig(),
	}
	out, code, err := RunCapture(ctx, spec)
	if err != nil {
		return remotePath, backupPath, err
	}
	if code == 3 {
		return remotePath, backupPath, fmt.Errorf("backend_dir 不存在: %s", t.BackendDir)
	}
	if code != 0 || !strings.Contains(out, "MOE_WRITE_OK") {
		return remotePath, backupPath, fmt.Errorf("写入失败 exit=%d: %s", code, strings.TrimSpace(out))
	}
	return remotePath, backupPath, nil
}

func joinRemotePath(dir, file string) string {
	dir = strings.TrimRight(strings.TrimSpace(dir), "/")
	return dir + "/" + file
}

func extractBetweenMarkers(out, begin, end string) string {
	i := strings.Index(out, begin)
	if i < 0 {
		return strings.TrimSpace(out)
	}
	i += len(begin)
	rest := out[i:]
	j := strings.Index(rest, end)
	if j < 0 {
		return strings.TrimSpace(rest)
	}
	return strings.TrimSpace(rest[:j])
}
