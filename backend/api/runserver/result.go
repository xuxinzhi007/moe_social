package runserver

import (
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

// StartResult API 启动结果（PK-4 前置层需要 ServiceContext）。
type StartResult struct {
	Server *rest.Server
	Svc    *svc.ServiceContext
	Host   string
	Port   int
}
