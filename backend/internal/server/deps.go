package server

import (
	"net/http"

	adminapphttp "backend/internal/server/protohttp/adminapp"
	platformhttp "backend/internal/server/protohttp/platform"
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
	UIHandler      http.HandlerFunc
	OpenAPIHandler http.HandlerFunc
	JSONHandler    http.HandlerFunc
}

func (d DocsHTTPDeps) Valid() bool {
	return d.UIHandler != nil || d.OpenAPIHandler != nil || d.JSONHandler != nil
}

type HTTPServerDeps struct {
	Ops       OpsHTTPDeps
	Proto     ProtoHTTPDeps
	Transport transport.Deps
	Docs      DocsHTTPDeps
}

func (d HTTPServerDeps) Valid() bool {
	return d.Ops.MoeAdmin != nil || d.Ops.AdminApp != nil || d.Ops.DB != nil || protoHTTPDepsValid(d.Proto) || d.Transport.Valid() || d.Docs.Valid()
}

func protoHTTPDepsValid(d ProtoHTTPDeps) bool {
	return d.LandingApp != nil || d.CheckinApp != nil || d.AchievementApp != nil || d.PostApp != nil || d.GiftApp != nil || d.GameApp != nil || d.LifeApp != nil || d.CompanionApp != nil || d.PetApp != nil || d.UserApp != nil || d.CommentApp != nil || d.CommunityApp != nil || d.ChatApp != nil || d.NotifyApp != nil || d.BehaviorApp != nil || d.AIApp != nil || d.LLMApp != nil || d.MediaApp != nil || d.VipAdmin != nil || d.MoeAdmin != nil || d.AdminApp != nil || d.MoeInferenceConfig.BaseUrl != "" || adminAppDepsValid(d.AdminAppDeps) || platformDepsValid(d.PlatformDeps)
}

func adminAppDepsValid(d adminapphttp.Deps) bool {
	return d.AIApp != nil || d.Runtime != nil || d.RecordAudit != nil
}

func platformDepsValid(d platformhttp.Deps) bool {
	return d.PublicAPIBaseURL != "" || d.AdminApp != nil || d.MoeAdmin != nil || d.UserApp != nil || d.LLMApp != nil || d.ModelCache != nil || d.InferenceConfig.BaseURL != "" || d.VoiceConfig.AppID != "" || d.VoiceConfig.AppCertificate != "" || d.ConfigSnapshot.InferenceBaseURL != ""
}
