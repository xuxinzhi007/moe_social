//go:build hybrid

package runserver

import (
	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/rest"
)

// StartResult API 启动结果（hybrid go-zero rest 回滚）。
type StartResult struct {
	Server *rest.Server
	Svc    *svc.ServiceContext
	Host   string
	Port   int
}
