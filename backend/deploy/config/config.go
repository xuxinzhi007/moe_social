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
	JobTimeoutSeconds  int          `mapstructure:"job_timeout_seconds"`
	GitHub             GitHubConfig     `mapstructure:"github"`
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
