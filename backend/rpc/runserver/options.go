package runserver

import "backend/utils"

// Options RPC 启动选项（Kratos / zrpc 共用）。
type Options struct {
	ConfigFile    string
	Migrate       utils.MigrateOptions
	EnableMonitor bool // 本地 :19011 pprof / JSON stats（moe-admin RPC 监控）
}
