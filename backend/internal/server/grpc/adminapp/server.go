package adminappgrpc

import (
	"context"

	adminv1 "backend/api/admin/v1"
	"backend/internal/platform/svc"
	adminapp "backend/internal/service/admin"
	aiapp "backend/internal/service/ai"
	vipadmin "backend/internal/service/vip"
)

// Server 实现 admin.v1.AdminApp HTTP/gRPC 适配（P1 迁移）。
type Server struct {
	adminv1.UnimplementedAdminAppServer
	app    *adminapp.AppService
	vip    *vipadmin.AdminService
	ai     *aiapp.AppService
	svcCtx *svc.ServiceContext
}

// New 构造 AdminApp 服务。
func New(app *adminapp.AppService, vip *vipadmin.AdminService, opts ...Option) *Server {
	s := &Server{app: app, vip: vip}
	for _, o := range opts {
		o(s)
	}
	return s
}

func (s *Server) requireApp() (*adminapp.AppService, error) {
	if s.app == nil {
		return nil, errAdminAppNil
	}
	return s.app, nil
}

func (s *Server) requireVip() (*vipadmin.AdminService, error) {
	if s.vip == nil {
		return nil, errVipAdminNil
	}
	return s.vip, nil
}

func (s *Server) Ping(ctx context.Context, in *adminv1.PingRequest) (*adminv1.PingReply, error) {
	_ = ctx
	_ = in
	return &adminv1.PingReply{}, nil
}

func (s *Server) AdminBootstrapAccount(ctx context.Context, in *adminv1.AdminBootstrapAccountReq) (*adminv1.AdminBootstrapAccountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminBootstrapAccount(ctx, in)
}

func (s *Server) AdminLogin(ctx context.Context, in *adminv1.AdminLoginReq) (*adminv1.AdminLoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminLogin(ctx, in)
}

func (s *Server) AdminListAccounts(ctx context.Context, in *adminv1.AdminListAccountsReq) (*adminv1.AdminListAccountsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAccounts(ctx, in)
}

func (s *Server) AdminCreateAccount(ctx context.Context, in *adminv1.AdminCreateAccountReq) (*adminv1.AdminCreateAccountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateAccount(ctx, in)
}

func (s *Server) AdminUpdateAccount(ctx context.Context, in *adminv1.AdminUpdateAccountReq) (*adminv1.AdminUpdateAccountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateAccount(ctx, in)
}

func (s *Server) AdminDeleteAccount(ctx context.Context, in *adminv1.AdminDeleteAccountReq) (*adminv1.AdminDeleteAccountResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAccount(ctx, in)
}

func (s *Server) AdminBootstrapAchievements(ctx context.Context, in *adminv1.AdminBootstrapAchievementsReq) (*adminv1.AdminBootstrapAchievementsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.BootstrapAchievements(ctx, in)
}

func (s *Server) AdminListAiAgents(ctx context.Context, in *adminv1.AdminListAiAgentsReq) (*adminv1.AdminListAiAgentsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAiAgents(ctx, in)
}

func (s *Server) AdminDeleteAiAgent(ctx context.Context, in *adminv1.AdminDeleteAiAgentReq) (*adminv1.AdminDeleteAiAgentResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAiAgent(ctx, in)
}

func (s *Server) AdminListAnnouncements(ctx context.Context, in *adminv1.AdminListAnnouncementsReq) (*adminv1.AdminListAnnouncementsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAnnouncements(ctx, in)
}

func (s *Server) AdminCreateAnnouncement(ctx context.Context, in *adminv1.AdminCreateAnnouncementReq) (*adminv1.AdminCreateAnnouncementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateAnnouncement(ctx, in)
}

func (s *Server) AdminGetAnnouncement(ctx context.Context, in *adminv1.AdminGetAnnouncementReq) (*adminv1.AdminGetAnnouncementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetAnnouncement(ctx, in)
}

func (s *Server) AdminUpdateAnnouncement(ctx context.Context, in *adminv1.AdminUpdateAnnouncementReq) (*adminv1.AdminUpdateAnnouncementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateAnnouncement(ctx, in)
}

func (s *Server) AdminDeleteAnnouncement(ctx context.Context, in *adminv1.AdminDeleteAnnouncementReq) (*adminv1.AdminDeleteAnnouncementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteAnnouncement(ctx, in)
}

func (s *Server) AdminPublishAnnouncement(ctx context.Context, in *adminv1.AdminPublishAnnouncementReq) (*adminv1.AdminPublishAnnouncementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.PublishAnnouncement(ctx, in)
}

func (s *Server) AdminListAuditLogs(ctx context.Context, in *adminv1.AdminListAuditLogsReq) (*adminv1.AdminListAuditLogsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAuditLogs(ctx, in)
}

func (s *Server) AdminListComments(ctx context.Context, in *adminv1.AdminListCommentsReq) (*adminv1.AdminListCommentsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListComments(ctx, in)
}

func (s *Server) AdminDeleteComment(ctx context.Context, in *adminv1.AdminDeleteCommentReq) (*adminv1.AdminDeleteCommentResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteComment(ctx, in)
}

func (s *Server) AdminListGroups(ctx context.Context, in *adminv1.AdminListGroupsReq) (*adminv1.AdminListGroupsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListGroups(ctx, in)
}

func (s *Server) AdminDeleteGroup(ctx context.Context, in *adminv1.AdminDeleteGroupReq) (*adminv1.AdminDeleteGroupResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteGroup(ctx, in)
}

func (s *Server) AdminListGifts(ctx context.Context, in *adminv1.AdminListGiftsReq) (*adminv1.AdminListGiftsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminListGifts(ctx, in)
}

func (s *Server) AdminCreateGift(ctx context.Context, in *adminv1.AdminCreateGiftReq) (*adminv1.AdminCreateGiftResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminCreateGift(ctx, in)
}

func (s *Server) AdminGetGift(ctx context.Context, in *adminv1.AdminGetGiftReq) (*adminv1.AdminGetGiftResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminGetGift(ctx, in)
}

func (s *Server) AdminUpdateGift(ctx context.Context, in *adminv1.AdminUpdateGiftReq) (*adminv1.AdminUpdateGiftResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminUpdateGift(ctx, in)
}

func (s *Server) AdminDeleteGift(ctx context.Context, in *adminv1.AdminDeleteGiftReq) (*adminv1.AdminDeleteGiftResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminDeleteGift(ctx, in)
}

func (s *Server) AdminBootstrapGifts(ctx context.Context, in *adminv1.AdminBootstrapGiftsReq) (*adminv1.AdminBootstrapGiftsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminBootstrapGifts(ctx, in)
}

func (s *Server) AdminDedupeGifts(ctx context.Context, in *adminv1.AdminDedupeGiftsReq) (*adminv1.AdminDedupeGiftsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminDedupeGifts(ctx, in)
}

func (s *Server) AdminListAchievements(ctx context.Context, in *adminv1.AdminListAchievementsReq) (*adminv1.AdminListAchievementsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListAchievements(ctx, in)
}

func (s *Server) AdminUpdateAchievement(ctx context.Context, in *adminv1.AdminUpdateAchievementReq) (*adminv1.AdminUpdateAchievementResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	normalizeAchievementID(in)
	return app.UpdateAchievement(ctx, in)
}

func (s *Server) AdminListLevelConfigs(ctx context.Context, in *adminv1.AdminListLevelConfigsReq) (*adminv1.AdminListLevelConfigsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListLevelConfigs(ctx, in)
}

func (s *Server) AdminUpdateLevelConfig(ctx context.Context, in *adminv1.AdminUpdateLevelConfigReq) (*adminv1.AdminUpdateLevelConfigResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	normalizeLevelID(in)
	return app.UpdateLevelConfig(ctx, in)
}

func (s *Server) AdminBootstrapLevels(ctx context.Context, in *adminv1.AdminBootstrapLevelsReq) (*adminv1.AdminBootstrapLevelsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.BootstrapLevels(ctx, in)
}

func (s *Server) AdminBroadcastNotification(ctx context.Context, in *adminv1.AdminBroadcastNotificationReq) (*adminv1.AdminBroadcastNotificationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.BroadcastNotification(ctx, in)
}

func (s *Server) AdminSendNotification(ctx context.Context, in *adminv1.AdminSendNotificationReq) (*adminv1.AdminSendNotificationResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.SendNotification(ctx, in)
}

func (s *Server) AdminListGiftPurchaseOrders(ctx context.Context, in *adminv1.AdminListGiftPurchaseOrdersReq) (*adminv1.AdminListGiftPurchaseOrdersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListGiftPurchaseOrders(ctx, in)
}

func (s *Server) AdminListVipOrders(ctx context.Context, in *adminv1.AdminListVipOrdersReq) (*adminv1.AdminListVipOrdersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListVipOrders(ctx, in)
}

func (s *Server) AdminListPostReports(ctx context.Context, in *adminv1.AdminListPostReportsReq) (*adminv1.AdminListPostReportsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListPostReports(ctx, in)
}

func (s *Server) AdminListPosts(ctx context.Context, in *adminv1.AdminListPostsReq) (*adminv1.AdminListPostsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListPosts(ctx, in)
}

func (s *Server) AdminDeletePost(ctx context.Context, in *adminv1.AdminDeletePostReq) (*adminv1.AdminDeletePostResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeletePost(ctx, in)
}

func (s *Server) AdminListFollows(ctx context.Context, in *adminv1.AdminListFollowsReq) (*adminv1.AdminListFollowsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListFollows(ctx, in)
}

func (s *Server) AdminDeleteFollow(ctx context.Context, in *adminv1.AdminDeleteFollowReq) (*adminv1.AdminDeleteFollowResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteFollow(ctx, in)
}

func (s *Server) AdminListFriendRequests(ctx context.Context, in *adminv1.AdminListFriendRequestsReq) (*adminv1.AdminListFriendRequestsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListFriendRequests(ctx, in)
}

func (s *Server) AdminListTagDictionary(ctx context.Context, in *adminv1.AdminListTagDictionaryReq) (*adminv1.AdminListTagDictionaryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListTagDictionary(ctx, in)
}

func (s *Server) AdminCreateTagDictionary(ctx context.Context, in *adminv1.AdminCreateTagDictionaryReq) (*adminv1.AdminCreateTagDictionaryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CreateTagDictionary(ctx, in)
}

func (s *Server) AdminUpdateTagDictionary(ctx context.Context, in *adminv1.AdminUpdateTagDictionaryReq) (*adminv1.AdminUpdateTagDictionaryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateTagDictionary(ctx, in)
}

func (s *Server) AdminDeleteTagDictionary(ctx context.Context, in *adminv1.AdminDeleteTagDictionaryReq) (*adminv1.AdminDeleteTagDictionaryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteTagDictionary(ctx, in)
}

func (s *Server) AdminUpdateTopicTag(ctx context.Context, in *adminv1.AdminUpdateTopicTagReq) (*adminv1.AdminUpdateTopicTagResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateTopicTag(ctx, in)
}

func (s *Server) AdminDeleteTopicTag(ctx context.Context, in *adminv1.AdminDeleteTopicTagReq) (*adminv1.AdminDeleteTopicTagResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteTopicTag(ctx, in)
}

func (s *Server) AdminBootstrapTopicTags(ctx context.Context, in *adminv1.AdminBootstrapTopicTagsReq) (*adminv1.AdminBootstrapTopicTagsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.AdminBootstrapTopicTags(ctx, in)
}

func (s *Server) AdminListUsers(ctx context.Context, in *adminv1.AdminListUsersReq) (*adminv1.AdminListUsersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListUsers(ctx, in)
}

func (s *Server) AdminGetUser(ctx context.Context, in *adminv1.AdminGetUserReq) (*adminv1.AdminGetUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUser(ctx, in)
}

func (s *Server) AdminUpdateUser(ctx context.Context, in *adminv1.AdminUpdateUserReq) (*adminv1.AdminUpdateUserResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpdateUser(ctx, in)
}

func (s *Server) AdminGetUserProfile(ctx context.Context, in *adminv1.AdminGetUserProfileReq) (*adminv1.AdminGetUserProfileResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserProfile(ctx, in)
}

func (s *Server) AdminGetVipPlan(ctx context.Context, in *adminv1.AdminGetVipPlanReq) (*adminv1.AdminGetVipPlanResp, error) {
	vip, err := s.requireVip()
	if err != nil {
		return nil, err
	}
	return vip.AdminGetVipPlan(ctx, in)
}

func (s *Server) AdminUpdateVipPlan(ctx context.Context, in *adminv1.AdminUpdateVipPlanReq) (*adminv1.AdminUpdateVipPlanResp, error) {
	vip, err := s.requireVip()
	if err != nil {
		return nil, err
	}
	return vip.AdminUpdateVipPlan(ctx, in)
}

func (s *Server) AdminDeleteVipPlan(ctx context.Context, in *adminv1.AdminDeleteVipPlanReq) (*adminv1.AdminDeleteVipPlanResp, error) {
	vip, err := s.requireVip()
	if err != nil {
		return nil, err
	}
	return vip.AdminDeleteVipPlan(ctx, in)
}

func (s *Server) AdminBootstrapVipPlans(ctx context.Context, in *adminv1.AdminBootstrapVipPlansReq) (*adminv1.AdminBootstrapVipPlansResp, error) {
	vip, err := s.requireVip()
	if err != nil {
		return nil, err
	}
	return vip.AdminBootstrapVipPlans(ctx, in)
}

func normalizeAchievementID(in *adminv1.AdminUpdateAchievementReq) {
	if in == nil {
		return
	}
	if in.GetId() == "" && in.GetAchievementId() != "" {
		in.Id = in.GetAchievementId()
	}
}

func normalizeLevelID(in *adminv1.AdminUpdateLevelConfigReq) {
	if in == nil {
		return
	}
	if in.GetId() == 0 && in.GetLevelId() != 0 {
		in.Id = in.GetLevelId()
	}
}
