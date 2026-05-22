package config

import "strings"

// DeployTarget is a deployment environment (local agent host or remote SSH).
type DeployTarget struct {
	ID           string `mapstructure:"id" json:"id"`
	Label        string `mapstructure:"label" json:"label"`
	Kind         string `mapstructure:"kind" json:"kind"` // local | ssh
	Host         string `mapstructure:"host" json:"host,omitempty"`
	Port         int    `mapstructure:"port" json:"port,omitempty"`
	User         string `mapstructure:"user" json:"user,omitempty"`
	IdentityFile string `mapstructure:"identity_file" json:"identity_file,omitempty"`
	Password     string `mapstructure:"password" json:"-"` // 永不输出到 API
	BackendDir   string `mapstructure:"backend_dir" json:"backend_dir,omitempty"`
	ComposeFile  string `mapstructure:"compose_file" json:"compose_file,omitempty"`
	APIBaseURL   string `mapstructure:"api_base_url" json:"api_base_url,omitempty"`
}

// IsSSH reports remote SSH target.
func (t DeployTarget) IsSSH() bool {
	return t.Kind == "ssh"
}

// NormalizeTargets ensures local + valid ssh targets.
func (c *Config) NormalizeTargets() []DeployTarget {
	out := make([]DeployTarget, 0, len(c.Targets)+1)
	hasLocal := false
	for _, t := range c.Targets {
		if t.ID == "local" || t.Kind == "local" || t.Kind == "" {
			hasLocal = true
			t.ID = "local"
			t.Kind = "local"
			if t.Label == "" {
				t.Label = "本机 (Agent)"
			}
			out = append(out, t)
			continue
		}
		if t.Kind != "ssh" {
			continue
		}
		if t.Port <= 0 {
			t.Port = 22
		}
		if t.User == "" {
			t.User = "root"
		}
		if t.ComposeFile == "" {
			t.ComposeFile = c.ComposeFile
		}
		if t.Label == "" {
			t.Label = t.Host
		}
		out = append(out, t)
	}
	if !hasLocal {
		out = append([]DeployTarget{{
			ID:    "local",
			Label: "本机 (Agent)",
			Kind:  "local",
		}}, out...)
	}
	return out
}

// TargetByID finds a target or returns local default.
func (c *Config) TargetByID(id string) DeployTarget {
	id = strings.TrimSpace(id)
	if id == "" || id == "local" {
		for _, t := range c.NormalizeTargets() {
			if t.ID == "local" {
				return t
			}
		}
		return DeployTarget{ID: "local", Label: "本机 (Agent)", Kind: "local"}
	}
	for _, t := range c.NormalizeTargets() {
		if t.ID == id {
			return t
		}
	}
	return DeployTarget{ID: "local", Label: "本机 (Agent)", Kind: "local"}
}
