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
	giftv1 "backend/api/gift/v1"
	landingv1 "backend/api/landing/v1"
	llmv1 "backend/api/llm/v1"
	moepb "backend/api/moe/v1"
	notifyv1 "backend/api/notify/v1"
	postv1 "backend/api/post/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	grpcserver "backend/internal/server/grpc"
	achievementgrpc "backend/internal/server/grpc/achievement"
	admininsightsgrpc "backend/internal/server/grpc/admininsights"
	aigrpc "backend/internal/server/grpc/ai"
	behaviorgrpc "backend/internal/server/grpc/behavior"
	chatgrpc "backend/internal/server/grpc/chat"
	checkingrpc "backend/internal/server/grpc/checkin"
	commentgrpc "backend/internal/server/grpc/comment"
	communitygrpc "backend/internal/server/grpc/community"
	giftgrpc "backend/internal/server/grpc/gift"
	landinggrpc "backend/internal/server/grpc/landing"
	llmgrpc "backend/internal/server/grpc/llm"
	notifygrpc "backend/internal/server/grpc/notify"
	postgrpc "backend/internal/server/grpc/post"
	usergrpc "backend/internal/server/grpc/user"
	vipgrpc "backend/internal/server/grpc/vip"
	vipreadgrpc "backend/internal/server/grpc/vipread"
	achievementapp "backend/internal/service/achievement"
	adminapp "backend/internal/service/admin"
	aiapp "backend/internal/service/ai"
	behaviorapp "backend/internal/service/behavior"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	llmapp "backend/internal/service/llm"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// ProtoHTTPDeps proto HTTP 注册依赖（与 SocialGRPCDeps 同形，D0 官方 Register*HTTPServer）。
type ProtoHTTPDeps struct {
	LandingApp     *landingapp.AppService
	CheckinApp     *checkinapp.AppService
	AchievementApp *achievementapp.AppService
	PostApp        *postapp.AppService
	GiftApp        *giftapp.AppService
	UserApp        *userapp.AppService
	CommentApp     *commentapp.AppService
	CommunityApp   *communityapp.AppService
	ChatApp        *chatapp.AppService
	NotifyApp      *notifyapp.AppService
	BehaviorApp    *behaviorapp.AppService
	AIApp          *aiapp.AppService
	LLMApp         *llmapp.AppService
	VipAdmin       *vipadmin.AdminService
	MoeAdmin       *moeadmin.AdminService
	AdminApp       *adminapp.AppService
}

// RegisterProtoHTTP 注册 Kratos 官方 protoc-gen-go-http 路由（D0）。
func RegisterProtoHTTP(srv *khttp.Server, d ProtoHTTPDeps) {
	if srv == nil {
		return
	}
	if d.LandingApp != nil {
		landingv1.RegisterLandingHTTPServer(srv, landinggrpc.New(d.LandingApp))
	}
	if d.CheckinApp != nil {
		checkinv1.RegisterCheckinHTTPServer(srv, checkingrpc.New(d.CheckinApp))
	}
	if d.AchievementApp != nil {
		achievementv1.RegisterAchievementHTTPServer(srv, achievementgrpc.New(d.AchievementApp))
	}
	if d.PostApp != nil {
		postv1.RegisterPostServiceHTTPServer(srv, postgrpc.New(d.PostApp))
	}
	if d.GiftApp != nil {
		giftv1.RegisterGiftServiceHTTPServer(srv, giftgrpc.New(d.GiftApp))
	}
	if d.UserApp != nil {
		userv1.RegisterUserServiceHTTPServer(srv, usergrpc.New(d.UserApp))
	}
	if d.CommentApp != nil {
		commentv1.RegisterCommentServiceHTTPServer(srv, commentgrpc.New(d.CommentApp))
	}
	if d.CommunityApp != nil {
		communityv1.RegisterCommunityHTTPServer(srv, communitygrpc.New(d.CommunityApp))
	}
	if d.ChatApp != nil {
		chatv1.RegisterPrivateMessageServiceHTTPServer(srv, chatgrpc.New(d.ChatApp))
	}
	if d.NotifyApp != nil {
		notifyv1.RegisterNotifyServiceHTTPServer(srv, notifygrpc.New(d.NotifyApp))
	}
	if d.UserApp != nil {
		vipv1.RegisterVipServiceHTTPServer(srv, vipgrpc.New(d.UserApp))
	}
	if d.BehaviorApp != nil {
		behaviorv1.RegisterBehaviorAppHTTPServer(srv, behaviorgrpc.New(d.BehaviorApp))
	}
	if d.AIApp != nil {
		aiv1.RegisterAiResourcesHTTPServer(srv, aigrpc.New(d.AIApp))
	}
	if d.LLMApp != nil {
		llmv1.RegisterLlmChatHTTPServer(srv, llmgrpc.New(d.LLMApp))
	}
	if d.VipAdmin != nil {
		vipv1.RegisterVipReadAdminHTTPServer(srv, vipreadgrpc.New(d.VipAdmin))
	}
	if d.MoeAdmin != nil {
		moepb.RegisterMoeAdminHTTPServer(srv, grpcserver.New(d.MoeAdmin))
	}
	if d.AdminApp != nil {
		adminv1.RegisterAdminInsightsHTTPServer(srv, admininsightsgrpc.New(d.AdminApp))
	}
}
