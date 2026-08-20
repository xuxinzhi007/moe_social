package runserver

import (
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
)

func wireCommunityServices(rep *wireReporter, ctx *svc.ServiceContext) {
	if ctx == nil {
		return
	}
	if moewiring.BehaviorAPIInProcessEnabled() {
		behaviorApp, err := moewiring.NewAPIBehaviorService()
		if err != nil {
			rep.domainWarn("behavior", "db", err.Error())
		} else if behaviorApp != nil {
			ctx.BehaviorApp = behaviorApp
		}
	}
	if moewiring.PostAPIInProcessEnabled() {
		postApp, err := moewiring.NewAPIPostService()
		if err != nil {
			rep.domainWarn("post", "db", err.Error())
		} else if postApp != nil {
			ctx.PostApp = postApp
		}
	}
	if moewiring.CommentAPIInProcessEnabled() {
		commentApp, err := moewiring.NewAPICommentService()
		if err != nil {
			rep.domainWarn("comment", "db", err.Error())
		} else if commentApp != nil {
			ctx.CommentApp = commentApp
		}
	}
	if moewiring.CheckInAPIInProcessEnabled() {
		checkInApp, err := moewiring.NewAPICheckInService()
		if err != nil {
			rep.domainWarn("checkin", "db", err.Error())
		} else if checkInApp != nil {
			ctx.CheckInApp = checkInApp
		}
	}
	if moewiring.AchievementAPIInProcessEnabled() {
		achApp, err := moewiring.NewAPIAchievementService()
		if err != nil {
			rep.domainWarn("achievement", "db", err.Error())
		} else if achApp != nil {
			ctx.AchievementApp = achApp
		}
	}
	if moewiring.GiftAPIInProcessEnabled() {
		giftApp, err := moewiring.NewAPIGiftService()
		if err != nil {
			rep.domainWarn("gift", "db", err.Error())
		} else if giftApp != nil {
			ctx.GiftApp = giftApp
		}
	}
	if moewiring.BattleAPIInProcessEnabled() {
		battleApp, err := moewiring.NewAPIBattleService()
		if err != nil {
			rep.domainWarn("battle", "db", err.Error())
		} else if battleApp != nil {
			ctx.BattleApp = battleApp
		}
	}
	if moewiring.ChatAPIInProcessEnabled() {
		chatApp, err := moewiring.NewAPIChatService()
		if err != nil {
			rep.domainWarn("chat", "db", err.Error())
		} else if chatApp != nil {
			ctx.ChatApp = chatApp
		}
	}
	if moewiring.NotifyAPIInProcessEnabled() {
		notifyApp, err := moewiring.NewAPINotifyService()
		if err != nil {
			rep.domainWarn("notify", "none", err.Error())
		} else if notifyApp != nil {
			ctx.NotifyApp = notifyApp
		}
	}
	if moewiring.CommunityAPIInProcessEnabled() {
		communityApp, err := moewiring.NewAPICommunityService()
		if err != nil {
			rep.domainWarn("community", "db", err.Error())
		} else if communityApp != nil {
			ctx.CommunityApp = communityApp
		}
	}
}
