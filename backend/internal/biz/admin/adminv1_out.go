package adminbiz

import (
	"strconv"

	adminv1 "backend/api/admin/v1"
)

func GrowthStatsV1(stats *adminv1.AdminGrowthStats) *adminv1.AdminGetGrowthStatsResp {
	return &adminv1.AdminGetGrowthStatsResp{Stats: stats}
}

func ListAnnouncementsV1(items []*adminv1.AdminAnnouncementItem, total int32) *adminv1.AdminListAnnouncementsResp {
	return &adminv1.AdminListAnnouncementsResp{Items: items, Total: total}
}

func AnnouncementV1(item *adminv1.AdminAnnouncementItem) *adminv1.AdminGetAnnouncementResp {
	return &adminv1.AdminGetAnnouncementResp{Announcement: item}
}

func CreateAnnouncementV1(item *adminv1.AdminAnnouncementItem) *adminv1.AdminCreateAnnouncementResp {
	return &adminv1.AdminCreateAnnouncementResp{Announcement: item}
}

func UpdateAnnouncementV1(item *adminv1.AdminAnnouncementItem) *adminv1.AdminUpdateAnnouncementResp {
	return &adminv1.AdminUpdateAnnouncementResp{Announcement: item}
}

func PublishAnnouncementV1(item *adminv1.AdminAnnouncementItem, notificationsCreated, wsSent int32) *adminv1.AdminPublishAnnouncementResp {
	return &adminv1.AdminPublishAnnouncementResp{
		Announcement:          item,
		NotificationsCreated: notificationsCreated,
		WsSent:               wsSent,
	}
}

func ListAuditLogsV1(items []*adminv1.AdminAuditLogItem, total int32) *adminv1.AdminListAuditLogsResp {
	return &adminv1.AdminListAuditLogsResp{Items: items, Total: total}
}

func ListGiftsV1(gifts []*adminv1.Gift, total int32) *adminv1.AdminListGiftsResp {
	return &adminv1.AdminListGiftsResp{Gifts: gifts, Total: total}
}

func GiftV1(gift *adminv1.Gift) *adminv1.AdminGetGiftResp {
	return &adminv1.AdminGetGiftResp{Gift: gift}
}

func CreateGiftV1(gift *adminv1.Gift) *adminv1.AdminCreateGiftResp {
	return &adminv1.AdminCreateGiftResp{Gift: gift}
}

func UpdateGiftV1(gift *adminv1.Gift) *adminv1.AdminUpdateGiftResp {
	return &adminv1.AdminUpdateGiftResp{Gift: gift}
}

func ListUsersV1(users []*adminv1.User, total int32) *adminv1.AdminListUsersResp {
	return &adminv1.AdminListUsersResp{Users: users, Total: total}
}

func ListAchievementsV1(items []*adminv1.AdminAchievementItem, total int32) *adminv1.AdminListAchievementsResp {
	return &adminv1.AdminListAchievementsResp{Items: items, Total: total}
}

func ListMenusV1(items []*adminv1.AdminMenuItem) *adminv1.AdminListMenusResp {
	return &adminv1.AdminListMenusResp{Items: items}
}

func UpdateUserV1(user *adminv1.User) *adminv1.AdminUpdateUserResp {
	return &adminv1.AdminUpdateUserResp{User: user}
}

func UpdateAchievementV1(item *adminv1.AdminAchievementItem) *adminv1.AdminUpdateAchievementResp {
	return &adminv1.AdminUpdateAchievementResp{Item: item}
}

func UpsertMenuV1(item *adminv1.AdminMenuItem) *adminv1.AdminUpsertMenuResp {
	return &adminv1.AdminUpsertMenuResp{Menu: item}
}

func SendNotificationV1(id uint) *adminv1.AdminSendNotificationResp {
	return &adminv1.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(id), 10)}
}
