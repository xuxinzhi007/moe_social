package adminapp

import (
	"context"
	"strconv"
	chatbiz "backend/internal/biz/chat"
	notifybiz "backend/internal/biz/notify"
	adminv1 "backend/api/admin/v1"
	platformv1 "backend/api/platform/v1"
	adminbiz "backend/internal/biz/admin"
)

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
	annID, _ := strconv.ParseUint(item.GetId(), 10, 64)
	created, _ := notifybiz.BroadcastAnnouncement(ctx, s.notify, annID, item.GetTitle(), item.GetContent())
	wsSent := int32(chatbiz.BroadcastPush(chatbiz.BroadcastPushInput{
		Type: "announcement_published",
		Data: map[string]interface{}{
			"announcement_id": item.GetId(),
			"title":           item.GetTitle(),
			"content":         item.GetContent(),
		},
	}))
	return adminbiz.PublishAnnouncementV1(item, created, wsSent), nil
}

func (s *AppService) ListPublishedAnnouncements(ctx context.Context, in *platformv1.ListAnnouncementsReq) (*platformv1.ListAnnouncementsResp, error) {
	items, total, err := adminbiz.ListPublishedAnnouncements(ctx, s.store, in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &platformv1.ListAnnouncementsResp{Items: items, Total: total}, nil
}

func (s *AppService) GetPublishedAnnouncement(ctx context.Context, in *platformv1.GetAnnouncementReq) (*platformv1.GetAnnouncementResp, error) {
	item, err := adminbiz.GetPublishedAnnouncement(ctx, s.store, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return &platformv1.GetAnnouncementResp{Item: item}, nil
}

func (s *AppService) DeleteAnnouncement(ctx context.Context, in *adminv1.AdminDeleteAnnouncementReq) (*adminv1.AdminDeleteAnnouncementResp, error) {
	if err := adminbiz.DeleteAnnouncement(ctx, s.store, in.GetAnnouncementId()); err != nil {
		return nil, err
	}
	return &adminv1.AdminDeleteAnnouncementResp{}, nil
}
