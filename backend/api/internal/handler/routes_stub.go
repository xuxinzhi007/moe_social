//go:build !hybrid

package handler

import (
	"github.com/zeromicro/go-zero/rest"
)

// RegisterHandlers 生产默认空实现（P4-H）；Hybrid 回滚用 `-tags hybrid` 编译 routes.go。
func RegisterHandlers(server *rest.Server, serverCtx interface{}) {
	_ = server
	_ = serverCtx
}
