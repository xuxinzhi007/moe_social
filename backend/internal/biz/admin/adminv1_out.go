package adminbiz

import (
	"strconv"

	adminv1 "backend/api/admin/v1"
	"backend/rpc/pb/moe"
)

func GrowthStatsV1(stats *moe.AdminGrowthStats) *adminv1.AdminGetGrowthStatsResp {
	return &adminv1.AdminGetGrowthStatsResp{Stats: adminv1.AdminGrowthStatsFromMoe(stats)}
}

func ListAnnouncementsV1(items []*moe.AdminAnnouncementItem, total int32) *adminv1.AdminListAnnouncementsResp {
	out := make([]*adminv1.AdminAnnouncementItem, 0, len(items))
	for _, it := range items {
		out = append(out, adminv1.AdminAnnouncementItemFromMoe(it))
	}
	return &adminv1.AdminListAnnouncementsResp{Items: out, Total: total}
}

func AnnouncementV1(item *moe.AdminAnnouncementItem) *adminv1.AdminGetAnnouncementResp {
	return &adminv1.AdminGetAnnouncementResp{Announcement: adminv1.AdminAnnouncementItemFromMoe(item)}
}

func CreateAnnouncementV1(item *moe.AdminAnnouncementItem) *adminv1.AdminCreateAnnouncementResp {
	return &adminv1.AdminCreateAnnouncementResp{Announcement: adminv1.AdminAnnouncementItemFromMoe(item)}
}

func UpdateAnnouncementV1(item *moe.AdminAnnouncementItem) *adminv1.AdminUpdateAnnouncementResp {
	return &adminv1.AdminUpdateAnnouncementResp{Announcement: adminv1.AdminAnnouncementItemFromMoe(item)}
}

func PublishAnnouncementV1(item *moe.AdminAnnouncementItem) *adminv1.AdminPublishAnnouncementResp {
	return &adminv1.AdminPublishAnnouncementResp{Announcement: adminv1.AdminAnnouncementItemFromMoe(item)}
}

func ListAuditLogsV1(items []*moe.AdminAuditLogItem, total int32) *adminv1.AdminListAuditLogsResp {
	out := make([]*adminv1.AdminAuditLogItem, 0, len(items))
	for _, it := range items {
		out = append(out, adminv1.AdminAuditLogItemFromMoe(it))
	}
	return &adminv1.AdminListAuditLogsResp{Items: out, Total: total}
}

func ListGiftsV1(gifts []*moe.Gift, total int32) *adminv1.AdminListGiftsResp {
	out := make([]*adminv1.Gift, 0, len(gifts))
	for _, g := range gifts {
		out = append(out, adminv1.GiftFromMoe(g))
	}
	return &adminv1.AdminListGiftsResp{Gifts: out, Total: total}
}

func GiftV1(gift *moe.Gift) *adminv1.AdminGetGiftResp {
	return &adminv1.AdminGetGiftResp{Gift: adminv1.GiftFromMoe(gift)}
}

func CreateGiftV1(gift *moe.Gift) *adminv1.AdminCreateGiftResp {
	return &adminv1.AdminCreateGiftResp{Gift: adminv1.GiftFromMoe(gift)}
}

func UpdateGiftV1(gift *moe.Gift) *adminv1.AdminUpdateGiftResp {
	return &adminv1.AdminUpdateGiftResp{Gift: adminv1.GiftFromMoe(gift)}
}

func ListUsersV1(users []*moe.User, total int32) *adminv1.AdminListUsersResp {
	out := make([]*adminv1.User, 0, len(users))
	for _, u := range users {
		out = append(out, adminv1.UserFromMoe(u))
	}
	return &adminv1.AdminListUsersResp{Users: out, Total: total}
}

func ListAchievementsV1(items []*moe.AdminAchievementItem, total int32) *adminv1.AdminListAchievementsResp {
	out := make([]*adminv1.AdminAchievementItem, 0, len(items))
	for _, it := range items {
		out = append(out, adminv1.AdminAchievementItemFromMoe(it))
	}
	return &adminv1.AdminListAchievementsResp{Items: out, Total: total}
}

func ListMenusV1(items []*moe.AdminMenuItem) *adminv1.AdminListMenusResp {
	out := make([]*adminv1.AdminMenuItem, 0, len(items))
	for _, it := range items {
		out = append(out, adminv1.AdminMenuItemFromMoe(it))
	}
	return &adminv1.AdminListMenusResp{Items: out}
}

func UpdateUserV1(user *moe.User) *adminv1.AdminUpdateUserResp {
	return &adminv1.AdminUpdateUserResp{User: adminv1.UserFromMoe(user)}
}

func UpdateAchievementV1(item *moe.AdminAchievementItem) *adminv1.AdminUpdateAchievementResp {
	return &adminv1.AdminUpdateAchievementResp{Item: adminv1.AdminAchievementItemFromMoe(item)}
}

func UpsertMenuV1(item *moe.AdminMenuItem) *adminv1.AdminUpsertMenuResp {
	return &adminv1.AdminUpsertMenuResp{Menu: adminv1.AdminMenuItemFromMoe(item)}
}

func SendNotificationV1(id uint) *adminv1.AdminSendNotificationResp {
	return &adminv1.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(id), 10)}
}
