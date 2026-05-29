package runserver

import "backend/internal/platform/svc"

// StartResult API 启动结果（wire-only）。
type StartResult struct {
	Server any // 生产为 nil
	Svc    *svc.ServiceContext
	Host   string
	Port   int
}
