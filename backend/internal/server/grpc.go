package server

import (
	achievementv1 "backend/api/achievement/v1"
	chatv1 "backend/api/chat/v1"
	checkinv1 "backend/api/checkin/v1"
	commentv1 "backend/api/comment/v1"
	communityv1 "backend/api/community/v1"
	giftv1 "backend/api/gift/v1"
	landingv1 "backend/api/landing/v1"
	moepb "backend/api/moe/v1"
	notifyv1 "backend/api/notify/v1"
	postv1 "backend/api/post/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	grpcserver "backend/internal/server/grpc"
	achievementgrpc "backend/internal/server/grpc/achievement"
	chatgrpc "backend/internal/server/grpc/chat"
	checkingrpc "backend/internal/server/grpc/checkin"
	commentgrpc "backend/internal/server/grpc/comment"
	communitygrpc "backend/internal/server/grpc/community"
	giftgrpc "backend/internal/server/grpc/gift"
	landinggrpc "backend/internal/server/grpc/landing"
	notifygrpc "backend/internal/server/grpc/notify"
	postgrpc "backend/internal/server/grpc/post"
	usergrpc "backend/internal/server/grpc/user"
	vipgrpc "backend/internal/server/grpc/vip"
	achievementapp "backend/internal/service/achievement"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"

	"github.com/go-kratos/kratos/v2/transport/grpc"
	googlegrpc "google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// SocialGRPCDeps 12 域 + MoeAdmin gRPC 注册依赖。
type SocialGRPCDeps struct {
	LandingApp       *landingapp.AppService
	CheckinApp       *checkinapp.AppService
	AchievementApp   *achievementapp.AppService
	PostApp          *postapp.AppService
	GiftApp          *giftapp.AppService
	UserApp          *userapp.AppService
	CommentApp       *commentapp.AppService
	CommunityApp     *communityapp.AppService
	ChatApp          *chatapp.AppService
	NotifyApp        *notifyapp.AppService
	MoeAdmin         *moeadmin.AdminService
	RegisterMoeAdmin bool
	EnableReflection bool
}

// RegisterSocialGRPC 在 Kratos gRPC Server 上注册社交域服务（与 core-platform server/grpc.go 同形）。
func RegisterSocialGRPC(grpcSrv *grpc.Server, d SocialGRPCDeps) {
	if grpcSrv == nil {
		return
	}
	if d.LandingApp != nil {
		landingv1.RegisterLandingServer(grpcSrv, landinggrpc.New(d.LandingApp))
	}
	if d.CheckinApp != nil {
		checkinv1.RegisterCheckinServer(grpcSrv, checkingrpc.New(d.CheckinApp))
	}
	if d.AchievementApp != nil {
		achievementv1.RegisterAchievementServer(grpcSrv, achievementgrpc.New(d.AchievementApp))
	}
	if d.PostApp != nil {
		postv1.RegisterPostServiceServer(grpcSrv, postgrpc.New(d.PostApp))
	}
	if d.GiftApp != nil {
		giftv1.RegisterGiftServiceServer(grpcSrv, giftgrpc.New(d.GiftApp))
	}
	if d.UserApp != nil {
		userv1.RegisterUserServiceServer(grpcSrv, usergrpc.New(d.UserApp))
	}
	if d.CommentApp != nil {
		commentv1.RegisterCommentServiceServer(grpcSrv, commentgrpc.New(d.CommentApp))
	}
	if d.CommunityApp != nil {
		communityv1.RegisterCommunityServer(grpcSrv, communitygrpc.New(d.CommunityApp))
	}
	if d.ChatApp != nil {
		chatv1.RegisterPrivateMessageServiceServer(grpcSrv, chatgrpc.New(d.ChatApp))
	}
	if d.NotifyApp != nil {
		notifyv1.RegisterNotifyServiceServer(grpcSrv, notifygrpc.New(d.NotifyApp))
	}
	if d.UserApp != nil {
		vipv1.RegisterVipServiceServer(grpcSrv, vipgrpc.New(d.UserApp))
	}
	if d.RegisterMoeAdmin && d.MoeAdmin != nil {
		moepb.RegisterMoeAdminServer(grpcSrv, grpcserver.New(d.MoeAdmin))
	}
	if d.EnableReflection {
		if underlying := kratosUnderlyingGRPC(grpcSrv); underlying != nil {
			reflection.Register(underlying)
		}
	}
}

func kratosUnderlyingGRPC(srv *grpc.Server) *googlegrpc.Server {
	if srv == nil {
		return nil
	}
	type grpcGetter interface {
		GetServer() *googlegrpc.Server
	}
	if g, ok := any(srv).(grpcGetter); ok {
		return g.GetServer()
	}
	return nil
}
