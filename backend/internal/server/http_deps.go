package server

import (
	moeadminhttp "backend/internal/server/protohttp"
)

// ProtoHTTPDepsFromPilot 从 PilotDeps 提取 proto HTTP 注册依赖。
func ProtoHTTPDepsFromPilot(d PilotDeps) ProtoHTTPDeps {
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
	out.GameApp = s.GameApp
	out.UserApp = s.UserApp
	out.CommentApp = s.CommentApp
	out.CommunityApp = s.CommunityApp
	out.ChatApp = s.ChatApp
	out.NotifyApp = s.NotifyApp
	out.BehaviorApp = s.BehaviorApp
	out.AIApp = s.AIApp
	out.LLMApp = s.LLMApp
	out.MediaApp = s.MediaApp
	if s.Config.LLMInference.BaseUrl != "" {
		out.LLMInferenceBaseURL = s.Config.LLMInference.BaseUrl
	}
	out.VipAdmin = s.VipAdmin
	out.AdminApp = s.AdminApp
	out.SvcCtx = s
	return out
}

func moeAdminHTTPOptions(d ProtoHTTPDeps) []moeadminhttp.Option {
	if d.SvcCtx == nil {
		return nil
	}
	return []moeadminhttp.Option{moeadminhttp.WithInferenceConfig(d.SvcCtx.Config.LLMInference)}
}
