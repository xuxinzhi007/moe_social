package bootstrap

import (
	"context"

	"backend/internal/platform/appdb"
	"backend/utils"
)

// AfterWire starts in-process background tasks after HTTP wiring completes.
func AfterWire(parent context.Context, deps Deps) {
	RegisterSocialAchievementHooks()
	if db, err := appdb.Open(); err == nil {
		utils.StartPrivateMessageCleanup(db)
	}
	StartMoeBotScheduler(parent, deps)
	StartDreamScheduler(parent, deps)

	// Companion 后台任务：记忆清理 + 问候广播
	if deps.CompanionApp != nil {
		deps.CompanionApp.Start(parent)
	}
}
