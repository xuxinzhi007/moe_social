package moesocial

import (
	"strings"

	"backend/pkg/conf"
)

const (
	defaultUnifiedConfig = "config/config.yaml"
	defaultAPIFragment   = "api/etc/moe.yaml"
)

// StartupPaths PK-13：统一配置入口 + API 结构片段路径。
type StartupPaths struct {
	Unified     string
	APIFragment string
}

// ResolveStartupPaths 解析启动配置路径（-f 为 SSOT；片段可由 config.yaml runtime 段覆盖）。
func ResolveStartupPaths(unified, apiOverride string) StartupPaths {
	u := strings.TrimSpace(unified)
	if u == "" {
		u = defaultUnifiedConfig
	}
	api := strings.TrimSpace(apiOverride)
	if api != "" {
		return StartupPaths{Unified: u, APIFragment: api}
	}
	loadUnified(u)
	api = strings.TrimSpace(conf.Get().Runtime.APIConfigFragment)
	if api == "" {
		api = defaultAPIFragment
	}
	return StartupPaths{Unified: u, APIFragment: api}
}

// NormalizeOptions 填充 Options 的配置路径（Run 入口调用）。
func (o *Options) NormalizeOptions() {
	if o == nil {
		return
	}
	p := ResolveStartupPaths(o.UnifiedConfigFile, o.APIConfigFile)
	o.UnifiedConfigFile = p.Unified
	o.APIConfigFile = p.APIFragment
}

// loadUnified 让 pkg/conf 的缓存指向 -f 指定的文件。
//
// conf.LoadFile 的注释写的就是「对应 cmd/moe-social 的 -f 覆盖」，但此前它零调用方：
// -f 只影响片段路径与端口，DSN、JWT 密钥、图片等其余读者仍走 searchDirs，同一次启动
// 读两个文件。Makefile / Dockerfile / deploy/n100 传的 -f 都是 config/config.yaml，
// 与其 WorkingDirectory 下的 searchDirs[0] 是同一个文件，所以这次收敛对现有部署无变化。
//
// -f 读不到时回落 searchDirs，与迁移前 viperForUnified 的静默回退一致。
func loadUnified(unified string) {
	if p := strings.TrimSpace(unified); p != "" {
		if _, err := conf.LoadFile(p); err == nil {
			return
		}
	}
	_, _ = conf.Load()
}

func httpPortFromUnified(unified string) int {
	loadUnified(unified)
	return conf.HTTPPort()
}
