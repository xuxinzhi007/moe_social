//go:build !hybrid

package runserver

import "backend/api/internal/svc"

// StartResult API 启动结果（纯 Kratos / wire-only）。
type StartResult struct {
	Server any // 生产为 nil；hybrid 构建见 result_hybrid.go
	Svc    *svc.ServiceContext
	Host   string
	Port   int
}
