package server

import (
	"backend/internal/platform/svc"
	"backend/internal/server/transport"
	adminapp "backend/internal/service/admin"
	moeadmin "backend/internal/service/moe"

	"gorm.io/gorm"
)

type OpsHTTPDeps struct {
	MoeAdmin *moeadmin.AdminService
	AdminApp *adminapp.AppService
	DB       *gorm.DB
}

type DocsHTTPDeps struct {
	ServiceContext *svc.ServiceContext
}

type HTTPServerDeps struct {
	Ops       OpsHTTPDeps
	Proto     ProtoHTTPDeps
	Transport transport.Deps
	Docs      DocsHTTPDeps
}

func (d HTTPServerDeps) Valid() bool {
	return d.Ops.MoeAdmin != nil || d.Ops.AdminApp != nil || d.Ops.DB != nil || protoHTTPDepsValid(d.Proto) || d.Transport.Valid() || d.Docs.ServiceContext != nil
}

func protoHTTPDepsValid(d ProtoHTTPDeps) bool {
	return d.LandingApp != nil || d.CheckinApp != nil || d.AchievementApp != nil || d.PostApp != nil || d.GiftApp != nil || d.GameApp != nil || d.UserApp != nil || d.CommentApp != nil || d.CommunityApp != nil || d.ChatApp != nil || d.NotifyApp != nil || d.BehaviorApp != nil || d.AIApp != nil || d.LLMApp != nil || d.MediaApp != nil || d.VipAdmin != nil || d.MoeAdmin != nil || d.AdminApp != nil || d.SvcCtx != nil || d.LLMInferenceBaseURL != ""
}
