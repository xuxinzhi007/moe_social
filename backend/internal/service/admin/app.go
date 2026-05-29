// Package adminapp Admin 只读应用服务（Sprint S3）。
package adminapp

import (
	"context"

	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
	notifybiz "backend/internal/biz/notify"
	admindata "backend/internal/data/admin"
	communitydata "backend/internal/data/community"
	notifydata "backend/internal/data/notify"
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
func (s *AppService) GrowthStats(ctx context.Context) (*adminv1.AdminGetGrowthStatsResp, error) {
	stats, err := adminbiz.GrowthStats(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return adminbiz.GrowthStatsV1(stats), nil
}

// SchemaCatalog 数据目录。
func (s *AppService) SchemaCatalog(ctx context.Context) (*adminv1.AdminGetSchemaCatalogResp, error) {
	out, err := adminbiz.SchemaCatalog(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return out, nil
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
func (s *AppService) BroadcastNotification(ctx context.Context, in *adminv1.AdminBroadcastNotificationReq) (*adminv1.AdminBroadcastNotificationResp, error) {
	created, err := notifybiz.Broadcast(ctx, s.notify, in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBroadcastNotificationResp{NotificationsCreated: created}, nil
}

// SendNotification 向单用户发送系统通知。
func (s *AppService) SendNotification(ctx context.Context, in *adminv1.AdminSendNotificationReq) (*adminv1.AdminSendNotificationResp, error) {
	id, err := notifybiz.SendToUser(ctx, s.notify, in.GetUserId(), in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return adminbiz.SendNotificationV1(id), nil
}

func (s *AppService) ListAnnouncements(ctx context.Context, in *adminv1.AdminListAnnouncementsReq) (*adminv1.AdminListAnnouncementsResp, error) {
	items, total, err := adminbiz.ListAnnouncements(ctx, s.store, adminbiz.AnnouncementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(), Status: in.GetStatus(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListAnnouncementsV1(items, total), nil
}

func (s *AppService) GetAnnouncement(ctx context.Context, in *adminv1.AdminGetAnnouncementReq) (*adminv1.AdminGetAnnouncementResp, error) {
	item, err := adminbiz.GetAnnouncement(ctx, s.store, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return adminbiz.AnnouncementV1(item), nil
}

func (s *AppService) ListAuditLogs(ctx context.Context, in *adminv1.AdminListAuditLogsReq) (*adminv1.AdminListAuditLogsResp, error) {
	items, total, err := adminbiz.ListAuditLogs(ctx, s.store, adminbiz.AuditLogFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Action: in.GetAction(),
		Resource: in.GetResource(), AdminID: in.GetAdminId(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListAuditLogsV1(items, total), nil
}

func (s *AppService) CreateAnnouncement(ctx context.Context, in *adminv1.AdminCreateAnnouncementReq) (*adminv1.AdminCreateAnnouncementResp, error) {
	item, err := adminbiz.CreateAnnouncement(ctx, s.store, in.GetTitle(), in.GetContent(), in.GetCreatedBy())
	if err != nil {
		return nil, err
	}
	return adminbiz.CreateAnnouncementV1(item), nil
}

func (s *AppService) UpdateAnnouncement(ctx context.Context, in *adminv1.AdminUpdateAnnouncementReq) (*adminv1.AdminUpdateAnnouncementResp, error) {
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
	return adminbiz.UpdateAnnouncementV1(item), nil
}

func (s *AppService) PublishAnnouncement(ctx context.Context, in *adminv1.AdminPublishAnnouncementReq) (*adminv1.AdminPublishAnnouncementResp, error) {
	item, err := adminbiz.PublishAnnouncement(ctx, s.store, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return adminbiz.PublishAnnouncementV1(item), nil
}

func (s *AppService) DeleteAnnouncement(ctx context.Context, in *adminv1.AdminDeleteAnnouncementReq) (*adminv1.AdminDeleteAnnouncementResp, error) {
	if err := adminbiz.DeleteAnnouncement(ctx, s.store, in.GetAnnouncementId()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteAnnouncementResp{}, nil
}

func (s *AppService) AdminListGifts(ctx context.Context, in *adminv1.AdminListGiftsReq) (*adminv1.AdminListGiftsResp, error) {
	gifts, total, err := adminbiz.ListGifts(ctx, s.db, adminbiz.GiftPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListGiftsV1(gifts, total), nil
}

func (s *AppService) AdminGetGift(ctx context.Context, in *adminv1.AdminGetGiftReq) (*adminv1.AdminGetGiftResp, error) {
	gift, err := adminbiz.GetGift(ctx, s.db, in.GetGiftId())
	if err != nil {
		return nil, err
	}
	return adminbiz.GiftV1(gift), nil
}

func (s *AppService) AdminCreateGift(ctx context.Context, in *adminv1.AdminCreateGiftReq) (*adminv1.AdminCreateGiftResp, error) {
	gift, err := adminbiz.CreateGift(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return adminbiz.CreateGiftV1(gift), nil
}

func (s *AppService) AdminUpdateGift(ctx context.Context, in *adminv1.AdminUpdateGiftReq) (*adminv1.AdminUpdateGiftResp, error) {
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
	return adminbiz.UpdateGiftV1(gift), nil
}

func (s *AppService) AdminDeleteGift(ctx context.Context, in *adminv1.AdminDeleteGiftReq) (*adminv1.AdminDeleteGiftResp, error) {
	if err := adminbiz.DeleteGift(ctx, s.db, in.GetGiftId()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteGiftResp{}, nil
}

func (s *AppService) AdminBootstrapGifts(ctx context.Context, in *adminv1.AdminBootstrapGiftsReq) (*adminv1.AdminBootstrapGiftsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapGifts(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapGiftsResp{Created: created}, nil
}

func (s *AppService) AdminDedupeGifts(ctx context.Context, in *adminv1.AdminDedupeGiftsReq) (*adminv1.AdminDedupeGiftsResp, error) {
	_ = in
	removed, err := adminbiz.DeduplicateGiftsByName(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminDedupeGiftsResp{Removed: removed}, nil
}

func (s *AppService) AdminBootstrapTopicTags(ctx context.Context, in *adminv1.AdminBootstrapTopicTagsReq) (*adminv1.AdminBootstrapTopicTagsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapTopicTags(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapTopicTagsResp{Created: created}, nil
}

func (s *AppService) ListUsers(ctx context.Context, in *adminv1.AdminListUsersReq) (*adminv1.AdminListUsersResp, error) {
	users, total, err := adminbiz.ListUsers(ctx, s.store, adminbiz.UserPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListUsersV1(users, total), nil
}

func (s *AppService) ListAchievements(ctx context.Context, in *adminv1.AdminListAchievementsReq) (*adminv1.AdminListAchievementsResp, error) {
	items, total, err := adminbiz.ListAchievements(ctx, s.db, adminbiz.AchievementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.ListAchievementsV1(items, total), nil
}

func (s *AppService) ListMenus(ctx context.Context, in *adminv1.AdminListMenusReq) (*adminv1.AdminListMenusResp, error) {
	_ = in
	items, err := adminbiz.ListMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return adminbiz.ListMenusV1(items), nil
}

func (s *AppService) UpdateUser(ctx context.Context, in *adminv1.AdminUpdateUserReq) (*adminv1.AdminUpdateUserResp, error) {
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
	return adminbiz.UpdateUserV1(user), nil
}

func (s *AppService) UpdateAchievement(ctx context.Context, in *adminv1.AdminUpdateAchievementReq) (*adminv1.AdminUpdateAchievementResp, error) {
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
	return adminbiz.UpdateAchievementV1(item), nil
}

func (s *AppService) UpsertMenu(ctx context.Context, in *adminv1.AdminUpsertMenuReq) (*adminv1.AdminUpsertMenuResp, error) {
	item, err := adminbiz.UpsertMenu(ctx, s.store, adminbiz.UpsertMenuInput{
		Key: in.GetKey(), Kind: in.GetKind(), ParentKey: in.GetParentKey(), Path: in.GetPath(),
		Label: in.GetLabel(), Icon: in.GetIcon(), Caption: in.GetCaption(), Status: in.GetStatus(),
		AppDomain: in.GetAppDomain(), SortOrder: in.GetSortOrder(), DefaultOpen: in.GetDefaultOpen(),
		End: in.GetEnd(), ExternalHref: in.GetExternalHref(), Enabled: in.GetEnabled(),
	})
	if err != nil {
		return nil, err
	}
	return adminbiz.UpsertMenuV1(item), nil
}

func (s *AppService) DeleteMenu(ctx context.Context, in *adminv1.AdminDeleteMenuReq) (*adminv1.AdminDeleteMenuResp, error) {
	if err := adminbiz.DeleteMenu(ctx, s.store, in.GetMenuKey()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteMenuResp{}, nil
}

func (s *AppService) BootstrapAchievements(ctx context.Context, in *adminv1.AdminBootstrapAchievementsReq) (*adminv1.AdminBootstrapAchievementsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapAchievements(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapAchievementsResp{Created: created}, nil
}

func (s *AppService) BootstrapMenus(ctx context.Context, in *adminv1.AdminBootstrapMenusReq) (*adminv1.AdminBootstrapMenusResp, error) {
	_ = in
	created, err := adminbiz.BootstrapMenus(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapMenusResp{Created: created}, nil
}

func (s *AppService) ListAiChatSessions(ctx context.Context, in *adminv1.AdminListAiChatSessionsReq) (*adminv1.AdminListAiChatSessionsResp, error) {
	out, err := adminbiz.AdminListAiChatSessions(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListAiChatMessages(ctx context.Context, in *adminv1.AdminListAiChatMessagesReq) (*adminv1.AdminListAiChatMessagesResp, error) {
	out, err := adminbiz.AdminListAiChatMessages(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ExportAiChatMessages(ctx context.Context, in *adminv1.AdminExportAiChatMessagesReq) (*adminv1.AdminExportAiChatMessagesResp, error) {
	out, err := adminbiz.AdminExportAiChatMessages(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) AnalyticsOverview(ctx context.Context, in *adminv1.AdminGetMemoryStatsReq) (*adminv1.AdminAnalyticsOverviewResp, error) {
	out, err := adminbiz.AdminAnalyticsOverview(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListTopicTags(ctx context.Context, in *adminv1.AdminListTopicTagsReq) (*adminv1.AdminListTopicTagsResp, error) {
	out, err := adminbiz.AdminListTopicTags(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateTopicTag(ctx context.Context, in *adminv1.AdminCreateTopicTagReq) (*adminv1.AdminCreateTopicTagResp, error) {
	out, err := adminbiz.AdminCreateTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateTopicTag(ctx context.Context, in *adminv1.AdminUpdateTopicTagReq) (*adminv1.AdminUpdateTopicTagResp, error) {
	out, err := adminbiz.AdminUpdateTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteTopicTag(ctx context.Context, in *adminv1.AdminDeleteTopicTagReq) (*adminv1.AdminDeleteTopicTagResp, error) {
	out, err := adminbiz.AdminDeleteTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListTagDictionary(ctx context.Context, in *adminv1.AdminListTagDictionaryReq) (*adminv1.AdminListTagDictionaryResp, error) {
	out, err := adminbiz.AdminListTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateTagDictionary(ctx context.Context, in *adminv1.AdminCreateTagDictionaryReq) (*adminv1.AdminCreateTagDictionaryResp, error) {
	out, err := adminbiz.AdminCreateTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateTagDictionary(ctx context.Context, in *adminv1.AdminUpdateTagDictionaryReq) (*adminv1.AdminUpdateTagDictionaryResp, error) {
	out, err := adminbiz.AdminUpdateTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteTagDictionary(ctx context.Context, in *adminv1.AdminDeleteTagDictionaryReq) (*adminv1.AdminDeleteTagDictionaryResp, error) {
	out, err := adminbiz.AdminDeleteTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListAiAgents(ctx context.Context, in *adminv1.AdminListAiAgentsReq) (*adminv1.AdminListAiAgentsResp, error) {
	out, err := adminbiz.ListAiAgents(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteAiAgent(ctx context.Context, in *adminv1.AdminDeleteAiAgentReq) (*adminv1.AdminDeleteAiAgentResp, error) {
	out, err := adminbiz.DeleteAiAgent(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListFollows(ctx context.Context, in *adminv1.AdminListFollowsReq) (*adminv1.AdminListFollowsResp, error) {
	out, err := adminbiz.ListFollows(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteFollow(ctx context.Context, in *adminv1.AdminDeleteFollowReq) (*adminv1.AdminDeleteFollowResp, error) {
	out, err := adminbiz.DeleteFollow(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListPosts(ctx context.Context, in *adminv1.AdminListPostsReq) (*adminv1.AdminListPostsResp, error) {
	out, err := adminbiz.ListPosts(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeletePost(ctx context.Context, in *adminv1.AdminDeletePostReq) (*adminv1.AdminDeletePostResp, error) {
	out, err := adminbiz.DeletePost(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListComments(ctx context.Context, in *adminv1.AdminListCommentsReq) (*adminv1.AdminListCommentsResp, error) {
	out, err := adminbiz.ListComments(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteComment(ctx context.Context, in *adminv1.AdminDeleteCommentReq) (*adminv1.AdminDeleteCommentResp, error) {
	out, err := adminbiz.DeleteComment(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListGroups(ctx context.Context, in *adminv1.AdminListGroupsReq) (*adminv1.AdminListGroupsResp, error) {
	out, err := adminbiz.ListGroups(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteGroup(ctx context.Context, in *adminv1.AdminDeleteGroupReq) (*adminv1.AdminDeleteGroupResp, error) {
	out, err := adminbiz.DeleteGroup(ctx, communitydata.NewStore(s.db), in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListFriendRequests(ctx context.Context, in *adminv1.AdminListFriendRequestsReq) (*adminv1.AdminListFriendRequestsResp, error) {
	out, err := adminbiz.ListFriendRequests(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListPostReports(ctx context.Context, in *adminv1.AdminListPostReportsReq) (*adminv1.AdminListPostReportsResp, error) {
	out, err := adminbiz.ListPostReports(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListMemories(ctx context.Context, in *adminv1.AdminListMemoriesReq) (*adminv1.AdminListMemoriesResp, error) {
	out, err := adminbiz.ListMemories(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteMemory(ctx context.Context, in *adminv1.AdminDeleteMemoryReq) (*adminv1.AdminDeleteMemoryResp, error) {
	out, err := adminbiz.DeleteMemory(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetMemoryStats(ctx context.Context, in *adminv1.AdminGetMemoryStatsReq) (*adminv1.AdminGetMemoryStatsResp, error) {
	out, err := adminbiz.GetMemoryStats(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListAccounts(ctx context.Context, in *adminv1.AdminListAccountsReq) (*adminv1.AdminListAccountsResp, error) {
	out, err := adminbiz.ListAccounts(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateAccount(ctx context.Context, in *adminv1.AdminCreateAccountReq) (*adminv1.AdminCreateAccountResp, error) {
	out, err := adminbiz.CreateAccount(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateAccount(ctx context.Context, in *adminv1.AdminUpdateAccountReq) (*adminv1.AdminUpdateAccountResp, error) {
	out, err := adminbiz.UpdateAccount(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteAccount(ctx context.Context, in *adminv1.AdminDeleteAccountReq) (*adminv1.AdminDeleteAccountResp, error) {
	out, err := adminbiz.DeleteAccount(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetUser(ctx context.Context, in *adminv1.AdminGetUserReq) (*adminv1.AdminGetUserResp, error) {
	out, err := adminbiz.GetUser(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) GetUserProfile(ctx context.Context, in *adminv1.AdminGetUserProfileReq) (*adminv1.AdminGetUserProfileResp, error) {
	out, err := adminbiz.GetUserProfile(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) Dashboard(ctx context.Context, in *adminv1.AdminDashboardReq) (*adminv1.AdminDashboardResp, error) {
	out, err := adminbiz.Dashboard(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListLevelConfigs(ctx context.Context, in *adminv1.AdminListLevelConfigsReq) (*adminv1.AdminListLevelConfigsResp, error) {
	out, err := adminbiz.ListLevelConfigs(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateLevelConfig(ctx context.Context, in *adminv1.AdminUpdateLevelConfigReq) (*adminv1.AdminUpdateLevelConfigResp, error) {
	out, err := adminbiz.UpdateLevelConfig(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) BootstrapLevels(ctx context.Context, in *adminv1.AdminBootstrapLevelsReq) (*adminv1.AdminBootstrapLevelsResp, error) {
	out, err := adminbiz.BootstrapLevels(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListCheckInRewards(ctx context.Context, in *adminv1.AdminListCheckInRewardsReq) (*adminv1.AdminListCheckInRewardsResp, error) {
	out, err := adminbiz.ListCheckInRewards(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateCheckInReward(ctx context.Context, in *adminv1.AdminUpdateCheckInRewardReq) (*adminv1.AdminUpdateCheckInRewardResp, error) {
	out, err := adminbiz.UpdateCheckInReward(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListVipOrders(ctx context.Context, in *adminv1.AdminListVipOrdersReq) (*adminv1.AdminListVipOrdersResp, error) {
	out, err := adminbiz.ListVipOrders(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListGiftPurchaseOrders(ctx context.Context, in *adminv1.AdminListGiftPurchaseOrdersReq) (*adminv1.AdminListGiftPurchaseOrdersResp, error) {
	out, err := adminbiz.ListGiftPurchaseOrders(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// RecordAuditLog 写入管理端操作审计。
func (s *AppService) RecordAuditLog(ctx context.Context, in *adminv1.RecordAdminAuditLogReq) (*adminv1.RecordAdminAuditLogResp, error) {
	if err := adminbiz.RecordAuditLog(ctx, s.store, in); err != nil {
		return nil, err
	}
	return &adminv1.RecordAdminAuditLogResp{}, nil
}

// AdminLogin 管理端登录。
func (s *AppService) AdminLogin(ctx context.Context, in *adminv1.AdminLoginReq) (*adminv1.AdminLoginResp, error) {
	out, err := adminbiz.AdminLogin(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// AdminBootstrapAccount 引导默认超管。
func (s *AppService) AdminBootstrapAccount(ctx context.Context, in *adminv1.AdminBootstrapAccountReq) (*adminv1.AdminBootstrapAccountResp, error) {
	out, err := adminbiz.BootstrapAdminAccount(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}
