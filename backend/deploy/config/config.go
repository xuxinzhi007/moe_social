package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/viper"
)

// Config holds Deploy Agent settings.
type Config struct {
	Listen             string       `mapstructure:"listen"`
	Token              string       `mapstructure:"token"`
	WorkspaceRoot      string       `mapstructure:"workspace_root"`
	BackendDir         string       `mapstructure:"backend_dir"`
	ComposeFile        string       `mapstructure:"compose_file"`
	JobTimeoutSeconds  int              `mapstructure:"job_timeout_seconds"`
	// WindowsShell: auto | git-bash | cmd — 本机任务用哪种 shell（auto 检测到 Git 则用 Git Bash）
	WindowsShell string `mapstructure:"windows_shell"`
	// LocalPathExtra 追加到本机任务 PATH 最前（Win 用 ; 分隔，Mac/Linux 用 :）
	LocalPathExtra string `mapstructure:"local_path_extra"`
	GitHub         GitHubConfig `mapstructure:"github"`
	Targets            []DeployTarget   `mapstructure:"targets"`
	workspaceAbs       string
	backendAbs         string
}

// GitHubConfig optional integration for Releases / Actions.
type GitHubConfig struct {
	Owner      string `mapstructure:"owner"`
	Repo       string `mapstructure:"repo"`
	Token      string `mapstructure:"token"`
	WorkflowID string `mapstructure:"workflow_id"`
}

// Load reads YAML from path and resolves workspace directories.
func Load(path string) (*Config, error) {
	v := viper.New()
	v.SetConfigFile(path)
	if err := v.ReadInConfig(); err != nil {
		return nil, err
	}
	localPath := filepath.Join(filepath.Dir(path), "config.local.yaml")
	if st, err := os.Stat(localPath); err == nil && !st.IsDir() {
		v2 := viper.New()
		v2.SetConfigFile(localPath)
		if err := v2.ReadInConfig(); err != nil {
			return nil, fmt.Errorf("读取 config.local.yaml: %w", err)
		}
		if err := v.MergeConfigMap(v2.AllSettings()); err != nil {
			return nil, fmt.Errorf("合并 config.local.yaml: %w", err)
		}
	}
	var c Config
	if err := v.Unmarshal(&c); err != nil {
		return nil, err
	}
	if c.Listen == "" {
		c.Listen = "127.0.0.1:9100"
	}
	if c.Token == "" {
		c.Token = "change-me"
	}
	if c.BackendDir == "" {
		c.BackendDir = "backend"
	}
	if c.ComposeFile == "" {
		c.ComposeFile = "docker-compose.binary.yml"
	}
	if c.JobTimeoutSeconds <= 0 {
		c.JobTimeoutSeconds = 1800
	}
	if c.WorkspaceRoot == "" {
		c.WorkspaceRoot = "../.."
	}

	configDir := filepath.Dir(path)
	ws := c.WorkspaceRoot
	if !filepath.IsAbs(ws) {
		ws = filepath.Clean(filepath.Join(configDir, ws))
	}
	c.workspaceAbs = ws

	be := c.BackendDir
	if !filepath.IsAbs(be) {
		be = filepath.Clean(filepath.Join(ws, be))
	}
	c.backendAbs = be

	if st, err := os.Stat(c.workspaceAbs); err != nil || !st.IsDir() {
		return nil, fmt.Errorf("workspace_root 无效（解析为 %s）：请检查 deploy/config.yaml 或设置 MOE_DEPLOY_WORKSPACE", c.workspaceAbs)
	}
	if st, err := os.Stat(c.backendAbs); err != nil || !st.IsDir() {
		return nil, fmt.Errorf("backend_dir 无效（解析为 %s）", c.backendAbs)
	}

	return &c, nil
}

// WorkspaceAbs returns resolved repository root.
func (c *Config) WorkspaceAbs() string {
	return c.workspaceAbs
}

// BackendAbs returns resolved backend directory.
func (c *Config) BackendAbs() string {
	return c.backendAbs
}

// ComposeFileAbs returns docker compose file path under backend.
func (c *Config) ComposeFileAbs() string {
	return filepath.Join(c.backendAbs, c.ComposeFile)
}

// DefaultTarget prefers cloud SSH when configured.
func (c *Config) DefaultTarget() string {
	for _, t := range c.NormalizeTargets() {
		if t.ID == "cloud" && t.IsSSH() {
			return "cloud"
		}
	}
	for _, t := range c.NormalizeTargets() {
		if t.IsSSH() {
			return t.ID
		}
	}
	return "local"
}

// TokenFromRequest extracts deploy token from header or query.
func TokenFromRequest(authHeader, queryToken string) string {
	const prefix = "Bearer "
	if strings.HasPrefix(authHeader, prefix) {
		return strings.TrimSpace(authHeader[len(prefix):])
	}
	if t := strings.TrimSpace(authHeader); t != "" {
		return t
	}
	return strings.TrimSpace(queryToken)
}

// WindowsShellLabel returns mode, bash path, and display label for logs/API.
func WindowsShellLabel(c *Config) (mode, bashExe, label string) {
	mode, bashExe = c.ResolvedWindowsShell()
	switch mode {
	case "git-bash":
		label = "Git Bash"
		if bashExe != "" {
			label += " (" + bashExe + ")"
		}
	default:
		label = "cmd.exe"
	}
	return mode, bashExe, label
}

// ResolvedWindowsShell picks local shell on Windows (auto prefers Git Bash when installed).
func (c *Config) ResolvedWindowsShell() (mode string, bashExe string) {
	mode = strings.ToLower(strings.TrimSpace(c.WindowsShell))
	if v := strings.ToLower(strings.TrimSpace(os.Getenv("MOE_DEPLOY_WINDOWS_SHELL"))); v != "" {
		mode = v
	}
	if mode == "" {
		mode = "auto"
	}
	bash := findGitBashInConfig()
	switch mode {
	case "git-bash", "gitbash", "bash":
		if bash != "" {
			return "git-bash", bash
		}
		return "cmd", ""
	case "cmd", "powershell", "pwsh":
		return "cmd", ""
	case "auto":
		if bash != "" {
			return "git-bash", bash
		}
		return "cmd", ""
	default:
		return "cmd", ""
	}
}

func findGitBashInConfig() string {
	var candidates []string
	for _, key := range []string{"ProgramFiles", "ProgramFiles(x86)", "LocalAppData"} {
		if base := os.Getenv(key); base != "" {
			candidates = append(candidates, filepath.Join(base, "Git", "bin", "bash.exe"))
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		candidates = append(candidates,
			filepath.Join(home, "AppData", "Local", "Programs", "Git", "bin", "bash.exe"),
		)
	}
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

// EnvOverride applies MOE_DEPLOY_* environment variables.
func (c *Config) EnvOverride() {
	if v := os.Getenv("MOE_DEPLOY_TOKEN"); v != "" {
		c.Token = v
	}
	if v := os.Getenv("MOE_DEPLOY_LISTEN"); v != "" {
		c.Listen = v
	}
	if v := os.Getenv("MOE_DEPLOY_WORKSPACE"); v != "" {
		c.workspaceAbs = filepath.Clean(v)
		be := c.BackendDir
		if !filepath.IsAbs(be) {
			be = filepath.Join(c.workspaceAbs, be)
		}
		c.backendAbs = filepath.Clean(be)
	}
}
