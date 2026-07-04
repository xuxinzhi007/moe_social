package server

import (
	"backend/internal/platform/chatdelivery"
	"backend/internal/platform/svc"
	moeadminhttp "backend/internal/server/protohttp"
	"backend/internal/server/transport"
)

func HTTPServerDepsFromServiceContext(s *svc.ServiceContext) HTTPServerDeps {
	deps := HTTPServerDeps{}
	if s == nil {
		return deps
	}
	deps.Ops.MoeAdmin = s.Domains.Access.MoeAdmin
	deps.Ops.AdminApp = s.Domains.Access.AdminApp
	deps.Proto = ProtoHTTPDepsFromServiceContext(s)
	deps.Transport = transport.Deps{
		MoeAdmin: s.Domains.Access.MoeAdmin,
		ChatWS:   chatdelivery.ChatWSDepsFrom(s),
	}
	deps.Docs = DocsHTTPDeps{ServiceContext: s}
	return deps
}

func ProtoHTTPDepsFromServiceContext(s *svc.ServiceContext) ProtoHTTPDeps {
	out := ProtoHTTPDeps{}
	if s == nil {
		return out
	}
	out.LandingApp = s.Domains.Access.LandingApp
	out.CheckinApp = s.Domains.Community.CheckInApp
	out.AchievementApp = s.Domains.Community.AchievementApp
	out.PostApp = s.Domains.Community.PostApp
	out.GiftApp = s.Domains.Community.GiftApp
	out.GameApp = s.Domains.Game.GameApp
	out.UserApp = s.Domains.Access.UserApp
	out.CommentApp = s.Domains.Community.CommentApp
	out.CommunityApp = s.Domains.Community.CommunityApp
	out.ChatApp = s.Domains.Community.ChatApp
	out.NotifyApp = s.Domains.Community.NotifyApp
	out.BehaviorApp = s.Domains.Community.BehaviorApp
	out.AIApp = s.Domains.AI.AIApp
	out.LLMApp = s.Domains.AI.LLMApp
	out.MediaApp = s.Domains.Platform.MediaApp
	if s.Config.LLMInference.BaseUrl != "" {
		out.LLMInferenceBaseURL = s.Config.LLMInference.BaseUrl
	}
	out.VipAdmin = s.Domains.Access.VipAdmin
	out.MoeAdmin = s.Domains.Access.MoeAdmin
	out.AdminApp = s.Domains.Access.AdminApp
	out.SvcCtx = s
	return out
}

func moeAdminHTTPOptions(d ProtoHTTPDeps) []moeadminhttp.Option {
	if d.SvcCtx == nil {
		return nil
	}
	return []moeadminhttp.Option{moeadminhttp.WithInferenceConfig(d.SvcCtx.Config.LLMInference)}
}
