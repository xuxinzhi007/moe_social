package server

import (
	"backend/internal/server/httplegacy"
)

// ProtoHTTPDepsFromPilot 从 PilotDeps 提取 proto HTTP 注册依赖。
func ProtoHTTPDepsFromPilot(d httplegacy.PilotDeps) ProtoHTTPDeps {
	out := ProtoHTTPDeps{MoeAdmin: d.MoeAdmin}
	if d.Svc == nil {
		return out
	}
	s := d.Svc
	out.LandingApp = s.LandingApp
	out.CheckinApp = s.CheckInApp
	out.AchievementApp = s.AchievementApp
	out.PostApp = s.PostApp
	out.GiftApp = s.GiftApp
	out.UserApp = s.UserApp
	out.CommentApp = s.CommentApp
	out.CommunityApp = s.CommunityApp
	out.ChatApp = s.ChatApp
	out.NotifyApp = s.NotifyApp
	out.BehaviorApp = s.BehaviorApp
	out.AIApp = s.AIApp
	out.LLMApp = s.LLMApp
	out.VipAdmin = s.VipAdmin
	out.AdminApp = s.AdminApp
	return out
}
