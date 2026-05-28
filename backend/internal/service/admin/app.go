// Package adminapp Admin 只读应用服务（Sprint S3）。
package adminapp

import (
	"context"
	"strconv"

	adminbiz "backend/internal/biz/admin"
	notifybiz "backend/internal/biz/notify"
	admindata "backend/internal/data/admin"
	communitydata "backend/internal/data/community"
	notifydata "backend/internal/data/notify"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

// AppService Admin 只读 HTTP/RPC 应用层。
type AppService struct {
	db     *gorm.DB
	store  adminbiz.AdminStore
	notify notifybiz.NotifyStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		db:     db,
		store:  admindata.NewStore(db),
		notify: notifydata.NewStore(db),
	}
}

// GrowthStats 成长统计。
func (s *AppService) GrowthStats(ctx context.Context) (*moe.AdminGetGrowthStatsResp, error) {
	stats, err := adminbiz.GrowthStats(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &moe.AdminGetGrowthStatsResp{Stats: stats}, nil
}

// SchemaCatalog 数据目录。
func (s *AppService) SchemaCatalog(ctx context.Context) (*moe.AdminGetSchemaCatalogResp, error) {
	return adminbiz.SchemaCatalog(ctx, s.store)
}

// ReadRuntimeConfig 运行时配置视图。
func (s *AppService) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	return adminbiz.RuntimeConfigView()
}

// RuntimeOverview 进程内存与布局汇总。
func (s *AppService) RuntimeOverview(ctx context.Context) (*adminbiz.RuntimeOverviewResult, error) {
	return adminbiz.RuntimeOverview(ctx)
}

// BroadcastNotification 广播系统通知。
func (s *AppService) BroadcastNotification(ctx context.Context, in *moe.AdminBroadcastNotificationReq) (*moe.AdminBroadcastNotificationResp, error) {
	created, err := notifybiz.Broadcast(ctx, s.notify, in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return &moe.AdminBroadcastNotificationResp{NotificationsCreated: created}, nil
}

// SendNotification 向单用户发送系统通知。
func (s *AppService) SendNotification(ctx context.Context, in *moe.AdminSendNotificationReq) (*moe.AdminSendNotificationResp, error) {
	id, err := notifybiz.SendToUser(ctx, s.notify, in.GetUserId(), in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return &moe.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(id), 10)}, nil
}

func (s *AppService) ListAnnouncements(ctx context.Context, in *moe.AdminListAnnouncementsReq) (*moe.AdminListAnnouncementsResp, error) {
	items, total, err := adminbiz.ListAnnouncements(ctx, s.store, adminbiz.AnnouncementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(), Status: in.GetStatus(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminListAnnouncementsResp{Items: items, Total: total}, nil
}

func (s *AppService) GetAnnouncement(ctx context.Context, in *moe.AdminGetAnnouncementReq) (*moe.AdminGetAnnouncementResp, error) {
	item, err := adminbiz.GetAnnouncement(ctx, s.store, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return &moe.AdminGetAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) ListAuditLogs(ctx context.Context, in *moe.AdminListAuditLogsReq) (*moe.AdminListAuditLogsResp, error) {
	items, total, err := adminbiz.ListAuditLogs(ctx, s.store, adminbiz.AuditLogFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Action: in.GetAction(),
		Resource: in.GetResource(), AdminID: in.GetAdminId(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminListAuditLogsResp{Items: items, Total: total}, nil
}

func (s *AppService) CreateAnnouncement(ctx context.Context, in *moe.AdminCreateAnnouncementReq) (*moe.AdminCreateAnnouncementResp, error) {
	item, err := adminbiz.CreateAnnouncement(ctx, s.store, in.GetTitle(), in.GetContent(), in.GetCreatedBy())
	if err != nil {
		return nil, err
	}
	return &moe.AdminCreateAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) UpdateAnnouncement(ctx context.Context, in *moe.AdminUpdateAnnouncementReq) (*moe.AdminUpdateAnnouncementResp, error) {
	item, err := adminbiz.UpdateAnnouncement(ctx, s.store, adminbiz.UpdateAnnouncementInput{
		AnnouncementID: in.GetAnnouncementId(),
		Title:          in.GetTitle(),
		Content:        in.GetContent(),
		UpdateTitle:    in.GetUpdateTitle(),
		UpdateContent:  in.GetUpdateContent(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpdateAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) PublishAnnouncement(ctx context.Context, in *moe.AdminPublishAnnouncementReq) (*moe.AdminPublishAnnouncementResp, error) {
	item, err := adminbiz.PublishAnnouncement(ctx, s.store, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return &moe.AdminPublishAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) DeleteAnnouncement(ctx context.Context, in *moe.AdminDeleteAnnouncementReq) (*moe.AdminDeleteAnnouncementResp, error) {
	if err := adminbiz.DeleteAnnouncement(ctx, s.store, in.GetAnnouncementId()); err != nil {
		return nil, err
	}
	return &moe.AdminDeleteAnnouncementResp{}, nil
}

func (s *AppService) AdminListGifts(ctx context.Context, in *moe.AdminListGiftsReq) (*moe.AdminListGiftsResp, error) {
	gifts, total, err := adminbiz.ListGifts(ctx, s.db, adminbiz.GiftPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminListGiftsResp{Gifts: gifts, Total: total}, nil
}

func (s *AppService) AdminGetGift(ctx context.Context, in *moe.AdminGetGiftReq) (*moe.AdminGetGiftResp, error) {
	gift, err := adminbiz.GetGift(ctx, s.db, in.GetGiftId())
	if err != nil {
		return nil, err
	}
	return &moe.AdminGetGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminCreateGift(ctx context.Context, in *moe.AdminCreateGiftReq) (*moe.AdminCreateGiftResp, error) {
	gift, err := adminbiz.CreateGift(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return &moe.AdminCreateGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminUpdateGift(ctx context.Context, in *moe.AdminUpdateGiftReq) (*moe.AdminUpdateGiftResp, error) {
	gift, err := adminbiz.UpdateGift(ctx, s.db, adminbiz.UpdateGiftInput{
		GiftIDRaw:         in.GetGiftId(),
		Name:              in.GetName(),
		Price:             in.GetPrice(),
		Icon:              in.GetIcon(),
		Description:       in.GetDescription(),
		Category:          in.GetCategory(),
		SortOrder:         in.GetSortOrder(),
		UpdateName:        in.GetUpdateName(),
		UpdatePrice:       in.GetUpdatePrice(),
		UpdateIcon:        in.GetUpdateIcon(),
		UpdateDescription: in.GetUpdateDescription(),
		UpdateCategory:    in.GetUpdateCategory(),
		UpdateSortOrder:   in.GetUpdateSortOrder(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpdateGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminDeleteGift(ctx context.Context, in *moe.AdminDeleteGiftReq) (*moe.AdminDeleteGiftResp, error) {
	if err := adminbiz.DeleteGift(ctx, s.db, in.GetGiftId()); err != nil {
		return nil, err
	}
	return &moe.AdminDeleteGiftResp{}, nil
}

func (s *AppService) AdminBootstrapGifts(ctx context.Context, in *moe.AdminBootstrapGiftsReq) (*moe.AdminBootstrapGiftsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapGifts(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &moe.AdminBootstrapGiftsResp{Created: created}, nil
}

func (s *AppService) AdminDedupeGifts(ctx context.Context, in *moe.AdminDedupeGiftsReq) (*moe.AdminDedupeGiftsResp, error) {
	_ = in
	removed, err := adminbiz.DeduplicateGiftsByName(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &moe.AdminDedupeGiftsResp{Removed: removed}, nil
}

func (s *AppService) AdminBootstrapTopicTags(ctx context.Context, in *moe.AdminBootstrapTopicTagsReq) (*moe.AdminBootstrapTopicTagsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapTopicTags(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &moe.AdminBootstrapTopicTagsResp{Created: created}, nil
}

func (s *AppService) ListUsers(ctx context.Context, in *moe.AdminListUsersReq) (*moe.AdminListUsersResp, error) {
	users, total, err := adminbiz.ListUsers(ctx, s.store, adminbiz.UserPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminListUsersResp{Users: users, Total: total}, nil
}

func (s *AppService) ListAchievements(ctx context.Context, in *moe.AdminListAchievementsReq) (*moe.AdminListAchievementsResp, error) {
	items, total, err := adminbiz.ListAchievements(ctx, s.db, adminbiz.AchievementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminListAchievementsResp{Items: items, Total: total}, nil
}

func (s *AppService) ListMenus(ctx context.Context, in *moe.AdminListMenusReq) (*moe.AdminListMenusResp, error) {
	_ = in
	items, err := adminbiz.ListMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &moe.AdminListMenusResp{Items: items}, nil
}

func (s *AppService) UpdateUser(ctx context.Context, in *moe.AdminUpdateUserReq) (*moe.AdminUpdateUserResp, error) {
	user, err := adminbiz.UpdateUser(ctx, s.store, adminbiz.UpdateUserInput{
		UserID:          uint(in.GetUserId()),
		Role:            in.GetRole(),
		IsVip:           in.GetIsVip(),
		UpdateIsVip:     in.GetUpdateIsVip(),
		Signature:       in.GetSignature(),
		UpdateSignature: in.GetUpdateSignature(),
		Avatar:          in.GetAvatar(),
		UpdateAvatar:    in.GetUpdateAvatar(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpdateUserResp{User: user}, nil
}

func (s *AppService) UpdateAchievement(ctx context.Context, in *moe.AdminUpdateAchievementReq) (*moe.AdminUpdateAchievementResp, error) {
	item, err := adminbiz.UpdateAchievement(ctx, s.db, adminbiz.UpdateAchievementInput{
		ID: in.GetId(), Name: in.GetName(), Description: in.GetDescription(),
		Enabled: in.GetEnabled(), ExpReward: in.GetExpReward(), SortOrder: in.GetSortOrder(),
		UpdateName: in.GetUpdateName(), UpdateDescription: in.GetUpdateDescription(),
		UpdateEnabled: in.GetUpdateEnabled(), UpdateExpReward: in.GetUpdateExpReward(),
		UpdateSortOrder: in.GetUpdateSortOrder(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpdateAchievementResp{Item: item}, nil
}

func (s *AppService) UpsertMenu(ctx context.Context, in *moe.AdminUpsertMenuReq) (*moe.AdminUpsertMenuResp, error) {
	item, err := adminbiz.UpsertMenu(ctx, s.store, adminbiz.UpsertMenuInput{
		Key: in.GetKey(), Kind: in.GetKind(), ParentKey: in.GetParentKey(), Path: in.GetPath(),
		Label: in.GetLabel(), Icon: in.GetIcon(), Caption: in.GetCaption(), Status: in.GetStatus(),
		AppDomain: in.GetAppDomain(), SortOrder: in.GetSortOrder(), DefaultOpen: in.GetDefaultOpen(),
		End: in.GetEnd(), ExternalHref: in.GetExternalHref(), Enabled: in.GetEnabled(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.AdminUpsertMenuResp{Menu: item}, nil
}

func (s *AppService) DeleteMenu(ctx context.Context, in *moe.AdminDeleteMenuReq) (*moe.AdminDeleteMenuResp, error) {
	if err := adminbiz.DeleteMenu(ctx, s.store, in.GetMenuKey()); err != nil {
		return nil, err
	}
	return &moe.AdminDeleteMenuResp{}, nil
}

func (s *AppService) BootstrapAchievements(ctx context.Context, in *moe.AdminBootstrapAchievementsReq) (*moe.AdminBootstrapAchievementsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapAchievements(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &moe.AdminBootstrapAchievementsResp{Created: created}, nil
}

func (s *AppService) BootstrapMenus(ctx context.Context, in *moe.AdminBootstrapMenusReq) (*moe.AdminBootstrapMenusResp, error) {
	_ = in
	created, err := adminbiz.BootstrapMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &moe.AdminBootstrapMenusResp{Created: created}, nil
}

func (s *AppService) ListAiChatSessions(ctx context.Context, in *moe.AdminListAiChatSessionsReq) (*moe.AdminListAiChatSessionsResp, error) {
	return adminbiz.AdminListAiChatSessions(ctx, s.store, in)
}

func (s *AppService) ListAiChatMessages(ctx context.Context, in *moe.AdminListAiChatMessagesReq) (*moe.AdminListAiChatMessagesResp, error) {
	return adminbiz.AdminListAiChatMessages(ctx, s.store, in)
}

func (s *AppService) ExportAiChatMessages(ctx context.Context, in *moe.AdminExportAiChatMessagesReq) (*moe.AdminExportAiChatMessagesResp, error) {
	return adminbiz.AdminExportAiChatMessages(ctx, s.store, in)
}

func (s *AppService) AnalyticsOverview(ctx context.Context, in *moe.AdminGetMemoryStatsReq) (*moe.AdminAnalyticsOverviewResp, error) {
	return adminbiz.AdminAnalyticsOverview(ctx, s.store, in)
}

func (s *AppService) ListTopicTags(ctx context.Context, in *moe.AdminListTopicTagsReq) (*moe.AdminListTopicTagsResp, error) {
	return adminbiz.AdminListTopicTags(ctx, s.store, in)
}

func (s *AppService) CreateTopicTag(ctx context.Context, in *moe.AdminCreateTopicTagReq) (*moe.AdminCreateTopicTagResp, error) {
	return adminbiz.AdminCreateTopicTag(ctx, s.store, in)
}

func (s *AppService) UpdateTopicTag(ctx context.Context, in *moe.AdminUpdateTopicTagReq) (*moe.AdminUpdateTopicTagResp, error) {
	return adminbiz.AdminUpdateTopicTag(ctx, s.store, in)
}

func (s *AppService) DeleteTopicTag(ctx context.Context, in *moe.AdminDeleteTopicTagReq) (*moe.AdminDeleteTopicTagResp, error) {
	return adminbiz.AdminDeleteTopicTag(ctx, s.store, in)
}

func (s *AppService) ListTagDictionary(ctx context.Context, in *moe.AdminListTagDictionaryReq) (*moe.AdminListTagDictionaryResp, error) {
	return adminbiz.AdminListTagDictionary(ctx, s.store, in)
}

func (s *AppService) CreateTagDictionary(ctx context.Context, in *moe.AdminCreateTagDictionaryReq) (*moe.AdminCreateTagDictionaryResp, error) {
	return adminbiz.AdminCreateTagDictionary(ctx, s.store, in)
}

func (s *AppService) UpdateTagDictionary(ctx context.Context, in *moe.AdminUpdateTagDictionaryReq) (*moe.AdminUpdateTagDictionaryResp, error) {
	return adminbiz.AdminUpdateTagDictionary(ctx, s.store, in)
}

func (s *AppService) DeleteTagDictionary(ctx context.Context, in *moe.AdminDeleteTagDictionaryReq) (*moe.AdminDeleteTagDictionaryResp, error) {
	return adminbiz.AdminDeleteTagDictionary(ctx, s.store, in)
}

func (s *AppService) ListAiAgents(ctx context.Context, in *moe.AdminListAiAgentsReq) (*moe.AdminListAiAgentsResp, error) {
	return adminbiz.ListAiAgents(ctx, s.db, in)
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *moe.AdminDeleteAiAgentReq) (*moe.AdminDeleteAiAgentResp, error) {
	return adminbiz.DeleteAiAgent(ctx, s.db, in)
}

func (s *AppService) ListFollows(ctx context.Context, in *moe.AdminListFollowsReq) (*moe.AdminListFollowsResp, error) {
	return adminbiz.ListFollows(ctx, s.db, in)
}

func (s *AppService) DeleteFollow(ctx context.Context, in *moe.AdminDeleteFollowReq) (*moe.AdminDeleteFollowResp, error) {
	return adminbiz.DeleteFollow(ctx, s.db, in)
}

func (s *AppService) ListPosts(ctx context.Context, in *moe.AdminListPostsReq) (*moe.AdminListPostsResp, error) {
	return adminbiz.ListPosts(ctx, s.db, in)
}

func (s *AppService) DeletePost(ctx context.Context, in *moe.AdminDeletePostReq) (*moe.AdminDeletePostResp, error) {
	return adminbiz.DeletePost(ctx, s.db, in)
}

func (s *AppService) ListComments(ctx context.Context, in *moe.AdminListCommentsReq) (*moe.AdminListCommentsResp, error) {
	return adminbiz.ListComments(ctx, s.db, in)
}

func (s *AppService) DeleteComment(ctx context.Context, in *moe.AdminDeleteCommentReq) (*moe.AdminDeleteCommentResp, error) {
	return adminbiz.DeleteComment(ctx, s.db, in)
}

func (s *AppService) ListGroups(ctx context.Context, in *moe.AdminListGroupsReq) (*moe.AdminListGroupsResp, error) {
	return adminbiz.ListGroups(ctx, s.db, in)
}

func (s *AppService) DeleteGroup(ctx context.Context, in *moe.AdminDeleteGroupReq) (*moe.AdminDeleteGroupResp, error) {
	return adminbiz.DeleteGroup(ctx, communitydata.NewStore(s.db), in)
}

func (s *AppService) ListFriendRequests(ctx context.Context, in *moe.AdminListFriendRequestsReq) (*moe.AdminListFriendRequestsResp, error) {
	return adminbiz.ListFriendRequests(ctx, s.db, in)
}

func (s *AppService) ListPostReports(ctx context.Context, in *moe.AdminListPostReportsReq) (*moe.AdminListPostReportsResp, error) {
	return adminbiz.ListPostReports(ctx, s.db, in)
}

func (s *AppService) ListMemories(ctx context.Context, in *moe.AdminListMemoriesReq) (*moe.AdminListMemoriesResp, error) {
	return adminbiz.ListMemories(ctx, s.db, in)
}

func (s *AppService) DeleteMemory(ctx context.Context, in *moe.AdminDeleteMemoryReq) (*moe.AdminDeleteMemoryResp, error) {
	return adminbiz.DeleteMemory(ctx, s.db, in)
}

func (s *AppService) GetMemoryStats(ctx context.Context, in *moe.AdminGetMemoryStatsReq) (*moe.AdminGetMemoryStatsResp, error) {
	return adminbiz.GetMemoryStats(ctx, s.store, in)
}

func (s *AppService) ListAccounts(ctx context.Context, in *moe.AdminListAccountsReq) (*moe.AdminListAccountsResp, error) {
	return adminbiz.ListAccounts(ctx, s.db, in)
}

func (s *AppService) CreateAccount(ctx context.Context, in *moe.AdminCreateAccountReq) (*moe.AdminCreateAccountResp, error) {
	return adminbiz.CreateAccount(ctx, s.db, in)
}

func (s *AppService) UpdateAccount(ctx context.Context, in *moe.AdminUpdateAccountReq) (*moe.AdminUpdateAccountResp, error) {
	return adminbiz.UpdateAccount(ctx, s.db, in)
}

func (s *AppService) DeleteAccount(ctx context.Context, in *moe.AdminDeleteAccountReq) (*moe.AdminDeleteAccountResp, error) {
	return adminbiz.DeleteAccount(ctx, s.db, in)
}

func (s *AppService) GetUser(ctx context.Context, in *moe.AdminGetUserReq) (*moe.AdminGetUserResp, error) {
	return adminbiz.GetUser(ctx, s.store, in)
}

func (s *AppService) GetUserProfile(ctx context.Context, in *moe.AdminGetUserProfileReq) (*moe.AdminGetUserProfileResp, error) {
	return adminbiz.GetUserProfile(ctx, s.store, in)
}

func (s *AppService) Dashboard(ctx context.Context, in *moe.AdminDashboardReq) (*moe.AdminDashboardResp, error) {
	return adminbiz.Dashboard(ctx, s.store, in)
}

func (s *AppService) ListLevelConfigs(ctx context.Context, in *moe.AdminListLevelConfigsReq) (*moe.AdminListLevelConfigsResp, error) {
	return adminbiz.ListLevelConfigs(ctx, s.db, in)
}

func (s *AppService) UpdateLevelConfig(ctx context.Context, in *moe.AdminUpdateLevelConfigReq) (*moe.AdminUpdateLevelConfigResp, error) {
	return adminbiz.UpdateLevelConfig(ctx, s.db, in)
}

func (s *AppService) BootstrapLevels(ctx context.Context, in *moe.AdminBootstrapLevelsReq) (*moe.AdminBootstrapLevelsResp, error) {
	return adminbiz.BootstrapLevels(ctx, s.db, in)
}

func (s *AppService) ListCheckInRewards(ctx context.Context, in *moe.AdminListCheckInRewardsReq) (*moe.AdminListCheckInRewardsResp, error) {
	return adminbiz.ListCheckInRewards(ctx, s.db, in)
}

func (s *AppService) UpdateCheckInReward(ctx context.Context, in *moe.AdminUpdateCheckInRewardReq) (*moe.AdminUpdateCheckInRewardResp, error) {
	return adminbiz.UpdateCheckInReward(ctx, s.db, in)
}

func (s *AppService) ListVipOrders(ctx context.Context, in *moe.AdminListVipOrdersReq) (*moe.AdminListVipOrdersResp, error) {
	return adminbiz.ListVipOrders(ctx, s.db, in)
}

func (s *AppService) ListGiftPurchaseOrders(ctx context.Context, in *moe.AdminListGiftPurchaseOrdersReq) (*moe.AdminListGiftPurchaseOrdersResp, error) {
	return adminbiz.ListGiftPurchaseOrders(ctx, s.db, in)
}

// RecordAuditLog 写入管理端操作审计。
func (s *AppService) RecordAuditLog(ctx context.Context, in *moe.RecordAdminAuditLogReq) (*moe.RecordAdminAuditLogResp, error) {
	if err := adminbiz.RecordAuditLog(ctx, s.store, in); err != nil {
		return nil, err
	}
	return &moe.RecordAdminAuditLogResp{}, nil
}

// AdminLogin 管理端登录。
func (s *AppService) AdminLogin(ctx context.Context, in *moe.AdminLoginReq) (*moe.AdminLoginResp, error) {
	return adminbiz.AdminLogin(ctx, s.store, in)
}

// AdminBootstrapAccount 引导默认超管。
func (s *AppService) AdminBootstrapAccount(ctx context.Context, in *moe.AdminBootstrapAccountReq) (*moe.AdminBootstrapAccountResp, error) {
	return adminbiz.BootstrapAdminAccount(ctx, s.store, in)
}
