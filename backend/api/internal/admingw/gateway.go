package admingw

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"
	"backend/utils"

	"google.golang.org/grpc"
)

// Gateway Admin 只读 HTTP → kratos 试点 HTTP（灰度）→ biz → super RPC。
type Gateway struct {
	kratos *KratosHTTPClient
	local  *adminapp.AppService
	super  moe.SuperClient
}

// New 构造网关；kratos 启用时 Insights 读路径走 :19032。
func New(local *adminapp.AppService, legacy moe.SuperClient, kratos *KratosHTTPClient) *Gateway {
	return &Gateway{local: local, super: legacy, kratos: kratos}
}

func (g *Gateway) kratosHTTPReady() bool {
	return g != nil && g.kratos != nil && g.kratos.enabled()
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.kratosHTTPReady() {
		return "kratos_http"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) AdminGetGrowthStats(ctx context.Context, in *moe.AdminGetGrowthStatsReq, opts ...grpc.CallOption) (*moe.AdminGetGrowthStatsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GrowthStats(ctx)
	}
	return g.super.AdminGetGrowthStats(ctx, in, opts...)
}

func (g *Gateway) AdminGetSchemaCatalog(ctx context.Context, in *moe.AdminGetSchemaCatalogReq, opts ...grpc.CallOption) (*moe.AdminGetSchemaCatalogResp, error) {
	if g != nil && g.local != nil {
		return g.local.SchemaCatalog(ctx)
	}
	return g.super.AdminGetSchemaCatalog(ctx, in, opts...)
}

// ReadRuntimeConfig 运行时配置（无 super RPC，in_process 时走 biz）。
func (g *Gateway) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	if g != nil && g.local != nil {
		return g.local.ReadRuntimeConfig()
	}
	return utils.ReadRuntimeConfig()
}

func (g *Gateway) AdminBroadcastNotification(ctx context.Context, in *moe.AdminBroadcastNotificationReq, opts ...grpc.CallOption) (*moe.AdminBroadcastNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.BroadcastNotification(ctx, in)
	}
	return g.super.AdminBroadcastNotification(ctx, in, opts...)
}

func (g *Gateway) AdminSendNotification(ctx context.Context, in *moe.AdminSendNotificationReq, opts ...grpc.CallOption) (*moe.AdminSendNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendNotification(ctx, in)
	}
	return g.super.AdminSendNotification(ctx, in, opts...)
}

func (g *Gateway) AdminListAnnouncements(ctx context.Context, in *moe.AdminListAnnouncementsReq, opts ...grpc.CallOption) (*moe.AdminListAnnouncementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAnnouncements(ctx, in)
	}
	return g.super.AdminListAnnouncements(ctx, in, opts...)
}

func (g *Gateway) AdminGetAnnouncement(ctx context.Context, in *moe.AdminGetAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminGetAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetAnnouncement(ctx, in)
	}
	return g.super.AdminGetAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListAuditLogs(ctx context.Context, in *moe.AdminListAuditLogsReq, opts ...grpc.CallOption) (*moe.AdminListAuditLogsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAuditLogs(ctx, in)
	}
	return g.super.AdminListAuditLogs(ctx, in, opts...)
}

func (g *Gateway) AdminCreateAnnouncement(ctx context.Context, in *moe.AdminCreateAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminCreateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateAnnouncement(ctx, in)
	}
	return g.super.AdminCreateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAnnouncement(ctx context.Context, in *moe.AdminUpdateAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminUpdateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAnnouncement(ctx, in)
	}
	return g.super.AdminUpdateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminPublishAnnouncement(ctx context.Context, in *moe.AdminPublishAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminPublishAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.PublishAnnouncement(ctx, in)
	}
	return g.super.AdminPublishAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAnnouncement(ctx context.Context, in *moe.AdminDeleteAnnouncementReq, opts ...grpc.CallOption) (*moe.AdminDeleteAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAnnouncement(ctx, in)
	}
	return g.super.AdminDeleteAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListGifts(ctx context.Context, in *moe.AdminListGiftsReq, opts ...grpc.CallOption) (*moe.AdminListGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminListGifts(ctx, in)
	}
	return g.super.AdminListGifts(ctx, in, opts...)
}

func (g *Gateway) AdminGetGift(ctx context.Context, in *moe.AdminGetGiftReq, opts ...grpc.CallOption) (*moe.AdminGetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminGetGift(ctx, in)
	}
	return g.super.AdminGetGift(ctx, in, opts...)
}

func (g *Gateway) AdminCreateGift(ctx context.Context, in *moe.AdminCreateGiftReq, opts ...grpc.CallOption) (*moe.AdminCreateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminCreateGift(ctx, in)
	}
	return g.super.AdminCreateGift(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateGift(ctx context.Context, in *moe.AdminUpdateGiftReq, opts ...grpc.CallOption) (*moe.AdminUpdateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminUpdateGift(ctx, in)
	}
	return g.super.AdminUpdateGift(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteGift(ctx context.Context, in *moe.AdminDeleteGiftReq, opts ...grpc.CallOption) (*moe.AdminDeleteGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminDeleteGift(ctx, in)
	}
	return g.super.AdminDeleteGift(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapGifts(ctx context.Context, in *moe.AdminBootstrapGiftsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapGifts(ctx, in)
	}
	return g.super.AdminBootstrapGifts(ctx, in, opts...)
}

func (g *Gateway) AdminDedupeGifts(ctx context.Context, in *moe.AdminDedupeGiftsReq, opts ...grpc.CallOption) (*moe.AdminDedupeGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminDedupeGifts(ctx, in)
	}
	return g.super.AdminDedupeGifts(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapTopicTags(ctx context.Context, in *moe.AdminBootstrapTopicTagsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapTopicTagsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapTopicTags(ctx, in)
	}
	return g.super.AdminBootstrapTopicTags(ctx, in, opts...)
}

func (g *Gateway) AdminListUsers(ctx context.Context, in *moe.AdminListUsersReq, opts ...grpc.CallOption) (*moe.AdminListUsersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListUsers(ctx, in)
	}
	return g.super.AdminListUsers(ctx, in, opts...)
}

func (g *Gateway) AdminListAchievements(ctx context.Context, in *moe.AdminListAchievementsReq, opts ...grpc.CallOption) (*moe.AdminListAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAchievements(ctx, in)
	}
	return g.super.AdminListAchievements(ctx, in, opts...)
}

func (g *Gateway) AdminListMenus(ctx context.Context, in *moe.AdminListMenusReq, opts ...grpc.CallOption) (*moe.AdminListMenusResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListMenus(ctx, in)
	}
	return g.super.AdminListMenus(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateUser(ctx context.Context, in *moe.AdminUpdateUserReq, opts ...grpc.CallOption) (*moe.AdminUpdateUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateUser(ctx, in)
	}
	return g.super.AdminUpdateUser(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAchievement(ctx context.Context, in *moe.AdminUpdateAchievementReq, opts ...grpc.CallOption) (*moe.AdminUpdateAchievementResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAchievement(ctx, in)
	}
	return g.super.AdminUpdateAchievement(ctx, in, opts...)
}

func (g *Gateway) AdminUpsertMenu(ctx context.Context, in *moe.AdminUpsertMenuReq, opts ...grpc.CallOption) (*moe.AdminUpsertMenuResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpsertMenu(ctx, in)
	}
	return g.super.AdminUpsertMenu(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteMenu(ctx context.Context, in *moe.AdminDeleteMenuReq, opts ...grpc.CallOption) (*moe.AdminDeleteMenuResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteMenu(ctx, in)
	}
	return g.super.AdminDeleteMenu(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapAchievements(ctx context.Context, in *moe.AdminBootstrapAchievementsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapAchievementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapAchievements(ctx, in)
	}
	return g.super.AdminBootstrapAchievements(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapMenus(ctx context.Context, in *moe.AdminBootstrapMenusReq, opts ...grpc.CallOption) (*moe.AdminBootstrapMenusResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapMenus(ctx, in)
	}
	return g.super.AdminBootstrapMenus(ctx, in, opts...)
}

func (g *Gateway) AdminListAiChatSessions(ctx context.Context, in *moe.AdminListAiChatSessionsReq, opts ...grpc.CallOption) (*moe.AdminListAiChatSessionsResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListAiChatSessions(ctx, in)
	}
	if g != nil && g.local != nil {
		return g.local.ListAiChatSessions(ctx, in)
	}
	return g.super.AdminListAiChatSessions(ctx, in, opts...)
}

func (g *Gateway) AdminListAiChatMessages(ctx context.Context, in *moe.AdminListAiChatMessagesReq, opts ...grpc.CallOption) (*moe.AdminListAiChatMessagesResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListAiChatMessages(ctx, in)
	}
	if g != nil && g.local != nil {
		return g.local.ListAiChatMessages(ctx, in)
	}
	return g.super.AdminListAiChatMessages(ctx, in, opts...)
}

func (g *Gateway) AdminExportAiChatMessages(ctx context.Context, in *moe.AdminExportAiChatMessagesReq, opts ...grpc.CallOption) (*moe.AdminExportAiChatMessagesResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminExportAiChatMessages(ctx, in)
	}
	if g != nil && g.local != nil {
		return g.local.ExportAiChatMessages(ctx, in)
	}
	return g.super.AdminExportAiChatMessages(ctx, in, opts...)
}

func (g *Gateway) AdminAnalyticsOverview(ctx context.Context, in *moe.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*moe.AdminAnalyticsOverviewResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminAnalyticsOverview(ctx, in)
	}
	if g != nil && g.local != nil {
		return g.local.AnalyticsOverview(ctx, in)
	}
	return g.super.AdminAnalyticsOverview(ctx, in, opts...)
}

func (g *Gateway) AdminListTopicTags(ctx context.Context, in *moe.AdminListTopicTagsReq, opts ...grpc.CallOption) (*moe.AdminListTopicTagsResp, error) {
	if g != nil && g.kratosHTTPReady() {
		return g.kratos.AdminListTopicTags(ctx, in)
	}
	if g != nil && g.local != nil {
		return g.local.ListTopicTags(ctx, in)
	}
	return g.super.AdminListTopicTags(ctx, in, opts...)
}

func (g *Gateway) AdminCreateTopicTag(ctx context.Context, in *moe.AdminCreateTopicTagReq, opts ...grpc.CallOption) (*moe.AdminCreateTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateTopicTag(ctx, in)
	}
	return g.super.AdminCreateTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateTopicTag(ctx context.Context, in *moe.AdminUpdateTopicTagReq, opts ...grpc.CallOption) (*moe.AdminUpdateTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateTopicTag(ctx, in)
	}
	return g.super.AdminUpdateTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteTopicTag(ctx context.Context, in *moe.AdminDeleteTopicTagReq, opts ...grpc.CallOption) (*moe.AdminDeleteTopicTagResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteTopicTag(ctx, in)
	}
	return g.super.AdminDeleteTopicTag(ctx, in, opts...)
}

func (g *Gateway) AdminListTagDictionary(ctx context.Context, in *moe.AdminListTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminListTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListTagDictionary(ctx, in)
	}
	return g.super.AdminListTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminCreateTagDictionary(ctx context.Context, in *moe.AdminCreateTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminCreateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateTagDictionary(ctx, in)
	}
	return g.super.AdminCreateTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateTagDictionary(ctx context.Context, in *moe.AdminUpdateTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminUpdateTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateTagDictionary(ctx, in)
	}
	return g.super.AdminUpdateTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteTagDictionary(ctx context.Context, in *moe.AdminDeleteTagDictionaryReq, opts ...grpc.CallOption) (*moe.AdminDeleteTagDictionaryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteTagDictionary(ctx, in)
	}
	return g.super.AdminDeleteTagDictionary(ctx, in, opts...)
}

func (g *Gateway) AdminListAiAgents(ctx context.Context, in *moe.AdminListAiAgentsReq, opts ...grpc.CallOption) (*moe.AdminListAiAgentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAiAgents(ctx, in)
	}
	return g.super.AdminListAiAgents(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAiAgent(ctx context.Context, in *moe.AdminDeleteAiAgentReq, opts ...grpc.CallOption) (*moe.AdminDeleteAiAgentResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAiAgent(ctx, in)
	}
	return g.super.AdminDeleteAiAgent(ctx, in, opts...)
}

func (g *Gateway) AdminListFollows(ctx context.Context, in *moe.AdminListFollowsReq, opts ...grpc.CallOption) (*moe.AdminListFollowsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFollows(ctx, in)
	}
	return g.super.AdminListFollows(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteFollow(ctx context.Context, in *moe.AdminDeleteFollowReq, opts ...grpc.CallOption) (*moe.AdminDeleteFollowResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteFollow(ctx, in)
	}
	return g.super.AdminDeleteFollow(ctx, in, opts...)
}

func (g *Gateway) AdminListPosts(ctx context.Context, in *moe.AdminListPostsReq, opts ...grpc.CallOption) (*moe.AdminListPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPosts(ctx, in)
	}
	return g.super.AdminListPosts(ctx, in, opts...)
}

func (g *Gateway) AdminDeletePost(ctx context.Context, in *moe.AdminDeletePostReq, opts ...grpc.CallOption) (*moe.AdminDeletePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeletePost(ctx, in)
	}
	return g.super.AdminDeletePost(ctx, in, opts...)
}

func (g *Gateway) AdminListComments(ctx context.Context, in *moe.AdminListCommentsReq, opts ...grpc.CallOption) (*moe.AdminListCommentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListComments(ctx, in)
	}
	return g.super.AdminListComments(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteComment(ctx context.Context, in *moe.AdminDeleteCommentReq, opts ...grpc.CallOption) (*moe.AdminDeleteCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteComment(ctx, in)
	}
	return g.super.AdminDeleteComment(ctx, in, opts...)
}

func (g *Gateway) AdminListGroups(ctx context.Context, in *moe.AdminListGroupsReq, opts ...grpc.CallOption) (*moe.AdminListGroupsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListGroups(ctx, in)
	}
	return g.super.AdminListGroups(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteGroup(ctx context.Context, in *moe.AdminDeleteGroupReq, opts ...grpc.CallOption) (*moe.AdminDeleteGroupResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteGroup(ctx, in)
	}
	return g.super.AdminDeleteGroup(ctx, in, opts...)
}

func (g *Gateway) AdminListFriendRequests(ctx context.Context, in *moe.AdminListFriendRequestsReq, opts ...grpc.CallOption) (*moe.AdminListFriendRequestsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListFriendRequests(ctx, in)
	}
	return g.super.AdminListFriendRequests(ctx, in, opts...)
}

func (g *Gateway) AdminListPostReports(ctx context.Context, in *moe.AdminListPostReportsReq, opts ...grpc.CallOption) (*moe.AdminListPostReportsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListPostReports(ctx, in)
	}
	return g.super.AdminListPostReports(ctx, in, opts...)
}

func (g *Gateway) AdminListMemories(ctx context.Context, in *moe.AdminListMemoriesReq, opts ...grpc.CallOption) (*moe.AdminListMemoriesResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListMemories(ctx, in)
	}
	return g.super.AdminListMemories(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteMemory(ctx context.Context, in *moe.AdminDeleteMemoryReq, opts ...grpc.CallOption) (*moe.AdminDeleteMemoryResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteMemory(ctx, in)
	}
	return g.super.AdminDeleteMemory(ctx, in, opts...)
}

func (g *Gateway) AdminGetMemoryStats(ctx context.Context, in *moe.AdminGetMemoryStatsReq, opts ...grpc.CallOption) (*moe.AdminGetMemoryStatsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetMemoryStats(ctx, in)
	}
	return g.super.AdminGetMemoryStats(ctx, in, opts...)
}

func (g *Gateway) AdminListAccounts(ctx context.Context, in *moe.AdminListAccountsReq, opts ...grpc.CallOption) (*moe.AdminListAccountsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAccounts(ctx, in)
	}
	return g.super.AdminListAccounts(ctx, in, opts...)
}

func (g *Gateway) AdminCreateAccount(ctx context.Context, in *moe.AdminCreateAccountReq, opts ...grpc.CallOption) (*moe.AdminCreateAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateAccount(ctx, in)
	}
	return g.super.AdminCreateAccount(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAccount(ctx context.Context, in *moe.AdminUpdateAccountReq, opts ...grpc.CallOption) (*moe.AdminUpdateAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAccount(ctx, in)
	}
	return g.super.AdminUpdateAccount(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAccount(ctx context.Context, in *moe.AdminDeleteAccountReq, opts ...grpc.CallOption) (*moe.AdminDeleteAccountResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAccount(ctx, in)
	}
	return g.super.AdminDeleteAccount(ctx, in, opts...)
}

func (g *Gateway) AdminGetUser(ctx context.Context, in *moe.AdminGetUserReq, opts ...grpc.CallOption) (*moe.AdminGetUserResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUser(ctx, in)
	}
	return g.super.AdminGetUser(ctx, in, opts...)
}

func (g *Gateway) AdminGetUserProfile(ctx context.Context, in *moe.AdminGetUserProfileReq, opts ...grpc.CallOption) (*moe.AdminGetUserProfileResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetUserProfile(ctx, in)
	}
	return g.super.AdminGetUserProfile(ctx, in, opts...)
}

func (g *Gateway) AdminDashboard(ctx context.Context, in *moe.AdminDashboardReq, opts ...grpc.CallOption) (*moe.AdminDashboardResp, error) {
	if g != nil && g.local != nil {
		return g.local.Dashboard(ctx, in)
	}
	return g.super.AdminDashboard(ctx, in, opts...)
}

func (g *Gateway) AdminListLevelConfigs(ctx context.Context, in *moe.AdminListLevelConfigsReq, opts ...grpc.CallOption) (*moe.AdminListLevelConfigsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListLevelConfigs(ctx, in)
	}
	return g.super.AdminListLevelConfigs(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateLevelConfig(ctx context.Context, in *moe.AdminUpdateLevelConfigReq, opts ...grpc.CallOption) (*moe.AdminUpdateLevelConfigResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateLevelConfig(ctx, in)
	}
	return g.super.AdminUpdateLevelConfig(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapLevels(ctx context.Context, in *moe.AdminBootstrapLevelsReq, opts ...grpc.CallOption) (*moe.AdminBootstrapLevelsResp, error) {
	if g != nil && g.local != nil {
		return g.local.BootstrapLevels(ctx, in)
	}
	return g.super.AdminBootstrapLevels(ctx, in, opts...)
}

func (g *Gateway) AdminListCheckInRewards(ctx context.Context, in *moe.AdminListCheckInRewardsReq, opts ...grpc.CallOption) (*moe.AdminListCheckInRewardsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListCheckInRewards(ctx, in)
	}
	return g.super.AdminListCheckInRewards(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateCheckInReward(ctx context.Context, in *moe.AdminUpdateCheckInRewardReq, opts ...grpc.CallOption) (*moe.AdminUpdateCheckInRewardResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateCheckInReward(ctx, in)
	}
	return g.super.AdminUpdateCheckInReward(ctx, in, opts...)
}

func (g *Gateway) AdminListVipOrders(ctx context.Context, in *moe.AdminListVipOrdersReq, opts ...grpc.CallOption) (*moe.AdminListVipOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListVipOrders(ctx, in)
	}
	return g.super.AdminListVipOrders(ctx, in, opts...)
}

func (g *Gateway) AdminListGiftPurchaseOrders(ctx context.Context, in *moe.AdminListGiftPurchaseOrdersReq, opts ...grpc.CallOption) (*moe.AdminListGiftPurchaseOrdersResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListGiftPurchaseOrders(ctx, in)
	}
	return g.super.AdminListGiftPurchaseOrders(ctx, in, opts...)
}
