// Package gwutil P5-C：进程内 gateway 共用错误（Super 回退已移除）。
package gwutil

import "errors"

// ErrUnavailable 未配置进程内 App（单进程生产应始终为 in_process）。
var ErrUnavailable = errors.New("gateway: in-process app not configured")

// Route 返回网关路由标签。
func Route(hasLocal bool) string {
	if hasLocal {
		return "in_process"
	}
	return "none"
}
