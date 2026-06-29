package server

import (
	achievementv1 "backend/api/achievement/v1"
	adminv1 "backend/api/admin/v1"
	aiv1 "backend/api/ai/v1"
	behaviorv1 "backend/api/behavior/v1"
	chatv1 "backend/api/chat/v1"
	checkinv1 "backend/api/checkin/v1"
	commentv1 "backend/api/comment/v1"
	communityv1 "backend/api/community/v1"
	contentv1 "backend/api/content/v1"
	giftv1 "backend/api/gift/v1"
	landingv1 "backend/api/landing/v1"
	llmv1 "backend/api/llm/v1"
	moepb "backend/api/moe/v1"
	notifyv1 "backend/api/notify/v1"
	platformv1 "backend/api/platform/v1"
	postv1 "backend/api/post/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/internal/platform/svc"
	moeadminhttp "backend/internal/server/protohttp"
	achievementhttp "backend/internal/server/protohttp/achievement"
	adminapphttp "backend/internal/server/protohttp/adminapp"
	admininsightshttp "backend/internal/server/protohttp/admininsights"
	aihttp "backend/internal/server/protohttp/ai"
	behaviorhttp "backend/internal/server/protohttp/behavior"
	chathttp "backend/internal/server/protohttp/chat"
	checkinhttp "backend/internal/server/protohttp/checkin"
	commenthttp "backend/internal/server/protohttp/comment"
	communityhttp "backend/internal/server/protohttp/community"
	contenthttp "backend/internal/server/protohttp/content"
	gifthttp "backend/internal/server/protohttp/gift"
	landinghttp "backend/internal/server/protohttp/landing"
	llmhttp "backend/internal/server/protohttp/llm"
	mediahttp "backend/internal/server/protohttp/media"
	notifyhttp "backend/internal/server/protohttp/notify"
	platformhttp "backend/internal/server/protohttp/platform"
	posthttp "backend/internal/server/protohttp/post"
	userhttp "backend/internal/server/protohttp/user"
	viphttp "backend/internal/server/protohttp/vip"
	vipplanshttp "backend/internal/server/protohttp/vipplans"
	vipreadhttp "backend/internal/server/protohttp/vipread"
	achievementapp "backend/internal/service/achievement"
	adminapp "backend/internal/service/admin"
	aiapp "backend/internal/service/ai"
	behaviorapp "backend/internal/service/behavior"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	contentapp "backend/internal/service/content"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	llmapp "backend/internal/service/llm"
	mediaapp "backend/internal/service/media"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// ProtoHTTPDeps proto HTTP 注册依赖（与 SocialGRPCDeps 同形，D0 官方 Register*HTTPServer）。
type ProtoHTTPDeps struct {
	LandingApp          *landingapp.AppService
	CheckinApp          *checkinapp.AppService
	AchievementApp      *achievementapp.AppService
	PostApp             *postapp.AppService
	GiftApp             *giftapp.AppService
	UserApp             *userapp.AppService
	CommentApp          *commentapp.AppService
	CommunityApp        *communityapp.AppService
	ChatApp             *chatapp.AppService
	NotifyApp           *notifyapp.AppService
	BehaviorApp         *behaviorapp.AppService
	AIApp               *aiapp.AppService
	LLMApp              *llmapp.AppService
	MediaApp            *mediaapp.AppService
	LLMInferenceBaseURL string
	VipAdmin            *vipadmin.AdminService
	MoeAdmin            *moeadmin.AdminService
	AdminApp            *adminapp.AppService
	SvcCtx              *svc.ServiceContext
}

// RegisterProtoHTTP 注册 Kratos 官方 protoc-gen-go-http 路由（D0）。
func RegisterProtoHTTP(srv *khttp.Server, d ProtoHTTPDeps) {
	if srv == nil {
		return
	}
	if d.LandingApp != nil {
		landingv1.RegisterLandingHTTPServer(srv, landinghttp.New(d.LandingApp))
	}
	if d.CheckinApp != nil {
		checkinv1.RegisterCheckinHTTPServer(srv, checkinhttp.New(d.CheckinApp))
	}
	if d.AchievementApp != nil {
		achievementv1.RegisterAchievementHTTPServer(srv, achievementhttp.New(d.AchievementApp))
	}
	if d.PostApp != nil {
		postv1.RegisterPostServiceHTTPServer(srv, posthttp.New(d.PostApp))
	}
	if d.GiftApp != nil {
		giftv1.RegisterGiftServiceHTTPServer(srv, gifthttp.New(d.GiftApp))
	}
	if d.UserApp != nil {
		userv1.RegisterUserServiceHTTPServer(srv, userhttp.New(d.UserApp))
	}
	if d.CommentApp != nil {
		commentv1.RegisterCommentServiceHTTPServer(srv, commenthttp.New(d.CommentApp))
	}
	if d.CommunityApp != nil {
		communityv1.RegisterCommunityHTTPServer(srv, communityhttp.New(d.CommunityApp))
	}
	if d.ChatApp != nil {
		chatSrv := chathttp.New(d.ChatApp)
		chatv1.RegisterPrivateMessageServiceHTTPServer(srv, chatSrv)
		chatv1.RegisterPushNotificationServiceHTTPServer(srv, chatSrv)
	}
	chatv1.RegisterChatPresenceServiceHTTPServer(srv, chathttp.NewPresence())
	if d.NotifyApp != nil {
		notifyv1.RegisterNotifyServiceHTTPServer(srv, notifyhttp.New(d.NotifyApp))
	}
	if d.UserApp != nil {
		vipv1.RegisterVipServiceHTTPServer(srv, viphttp.New(d.UserApp))
	}
	if d.BehaviorApp != nil {
		behaviorv1.RegisterBehaviorAppHTTPServer(srv, behaviorhttp.New(d.BehaviorApp))
	}
	if d.AIApp != nil {
		aiv1.RegisterAiResourcesHTTPServer(srv, aihttp.New(d.AIApp))
	}
	if d.LLMApp != nil {
		llmv1.RegisterLlmChatHTTPServer(srv, llmhttp.New(d.LLMApp))
	}
	if d.MediaApp != nil {
		mediahttp.RegisterHTTPServer(srv, mediahttp.New(d.MediaApp))
	}
	contentv1.RegisterContentServiceHTTPServer(srv, contenthttp.New(contentapp.New()))
	if d.VipAdmin != nil {
		vipv1.RegisterVipReadAdminHTTPServer(srv, vipreadhttp.New(d.VipAdmin))
		vipv1.RegisterVipPlansHTTPServer(srv, vipplanshttp.New(d.VipAdmin))
	}
	if d.MoeAdmin != nil {
		moeSrv := moeadminhttp.New(d.MoeAdmin, moeAdminHTTPOptions(d)...)
		moepb.RegisterMoeAdminHTTPServer(srv, moeSrv)
	}
	if d.AdminApp != nil {
		adminv1.RegisterAdminInsightsHTTPServer(srv, admininsightshttp.New(d.AdminApp))
		adminOpts := []adminapphttp.Option{}
		if d.AIApp != nil {
			adminOpts = append(adminOpts, adminapphttp.WithAIApp(d.AIApp))
		}
		if d.SvcCtx != nil {
			adminOpts = append(adminOpts, adminapphttp.WithServiceContext(d.SvcCtx))
		}
		adminv1.RegisterAdminAppHTTPServer(srv, adminapphttp.New(d.AdminApp, d.VipAdmin, adminOpts...))
	}
	if d.SvcCtx != nil {
		platformv1.RegisterPlatformHTTPServer(srv, platformhttp.New(d.SvcCtx))
	}
}
