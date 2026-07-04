package bootstrap

import (
	"context"

	"backend/utils"
)

// AfterWire starts in-process background tasks after HTTP wiring completes.
func AfterWire(parent context.Context, deps Deps) {
	RegisterSocialAchievementHooks()
	if db := utils.GetDB(); db != nil {
		utils.StartPrivateMessageCleanup(db)
	}
	StartMoeBotScheduler(parent, deps)
	StartDreamScheduler(parent, deps)
}
