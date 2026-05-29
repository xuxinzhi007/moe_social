package bootstrap

import (
	"context"

	platformsvc "backend/internal/platform/svc"
	"backend/utils"
)

// AfterWire HTTP 装配完成后启动进程内后台任务（成就钩子、私信清理、Bot 调度）。
func AfterWire(parent context.Context, svc *platformsvc.ServiceContext) {
	RegisterSocialAchievementHooks()
	if db := utils.GetDB(); db != nil {
		utils.StartPrivateMessageCleanup(db)
	}
	StartMoeBotScheduler(parent, svc)
}
