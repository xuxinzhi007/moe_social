package adminbiz

import (
	"context"

	adminv1 "backend/api/admin/v1"
	platformv1 "backend/api/platform/v1"
	"backend/model"
)

// ListPublishedAnnouncements 用户侧：仅返回已发布公告。
func ListPublishedAnnouncements(ctx context.Context, store AdminStore, page, pageSize int32) ([]*platformv1.AnnouncementItem, int32, error) {
	items, total, err := ListAnnouncements(ctx, store, AnnouncementPage{
		Page: page, PageSize: pageSize, Status: model.AnnouncementStatusPublished,
	})
	if err != nil {
		return nil, 0, err
	}
	out := make([]*platformv1.AnnouncementItem, len(items))
	for i, item := range items {
		out[i] = adminAnnouncementToPublic(item)
	}
	return out, total, nil
}

// GetPublishedAnnouncement 用户侧公告详情（非 published 视为不存在）。
func GetPublishedAnnouncement(ctx context.Context, store AdminStore, idRaw string) (*platformv1.AnnouncementItem, error) {
	item, err := GetAnnouncement(ctx, store, idRaw)
	if err != nil {
		return nil, err
	}
	if item.GetStatus() != model.AnnouncementStatusPublished {
		return nil, ErrAnnouncementNotFound
	}
	return adminAnnouncementToPublic(item), nil
}

func adminAnnouncementToPublic(item *adminv1.AdminAnnouncementItem) *platformv1.AnnouncementItem {
	if item == nil {
		return nil
	}
	return &platformv1.AnnouncementItem{
		Id:          item.GetId(),
		Title:       item.GetTitle(),
		Content:     item.GetContent(),
		PublishedAt: item.GetPublishedAt(),
	}
}
