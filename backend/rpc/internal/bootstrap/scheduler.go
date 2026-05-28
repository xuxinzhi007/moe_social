package bootstrap

import (
	"context"

	"backend/rpc/internal/svc"
)

// StartMoeBotScheduler 启动 Moe Bot cron/smart 调度（仅在 RPC 进程）。
func StartMoeBotScheduler(parent context.Context, svc *svc.ServiceContext) {
	StartBotScheduler(parent, svc)
}
