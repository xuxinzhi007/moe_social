package moesocial

import (
	"fmt"
	"strings"

	"backend/internal/platform/yamlconf"
	"backend/utils"
)

// Options 单进程启动参数（PK-13：UnifiedConfigFile 为 SSOT，API 片段自动解析）。
type Options struct {
	UnifiedConfigFile string
	APIConfigFile     string
	Migrate           utils.MigrateOptions
}

// Run 启动 Kratos HTTP-only（:8888，proto + transport）。
func Run(opts Options) error {
	opts.NormalizeOptions()
	return runHTTPOnly(opts)
}

func externalHTTPPort(unified, apiFragment string) int {
	if p := httpPortFromUnified(unified); p > 0 {
		return p
	}
	var c struct {
		Port int `yaml:"Port"`
	}
	yamlconf.MustLoad(apiFragment, &c)
	if c.Port <= 0 {
		return 8888
	}
	return c.Port
}

func apiListenAddr(configFile string) string {
	var c struct {
		Host string `yaml:"Host"`
		Port int    `yaml:"Port"`
	}
	yamlconf.MustLoad(configFile, &c)
	if c.Port <= 0 {
		c.Port = 8888
	}
	host := strings.TrimSpace(c.Host)
	if host == "" {
		host = "0.0.0.0"
	}
	return normalizeListenAddr(fmt.Sprintf("%s:%d", host, c.Port), "8888")
}

func normalizeListenAddr(host, defaultPort string) string {
	host = strings.TrimSpace(host)
	if host == "" {
		host = "0.0.0.0:" + defaultPort
	}
	if strings.HasPrefix(host, ":") {
		host = "0.0.0.0" + host
	}
	if !strings.Contains(host, ":") {
		host = host + ":" + defaultPort
	}
	return strings.Replace(host, "0.0.0.0", "127.0.0.1", 1)
}
