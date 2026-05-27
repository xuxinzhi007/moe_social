// Package adminapp Admin 只读应用服务（Sprint S3）。
package adminapp

import (
	"context"
	"strconv"

	adminbiz "backend/internal/biz/admin"
	notifybiz "backend/internal/biz/notify"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

// AppService Admin 只读 HTTP/RPC 应用层。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// GrowthStats 成长统计。
func (s *AppService) GrowthStats(ctx context.Context) (*super.AdminGetGrowthStatsResp, error) {
	stats, err := adminbiz.GrowthStats(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &super.AdminGetGrowthStatsResp{Stats: stats}, nil
}

// SchemaCatalog 数据目录。
func (s *AppService) SchemaCatalog(ctx context.Context) (*super.AdminGetSchemaCatalogResp, error) {
	return adminbiz.SchemaCatalog(ctx, s.db)
}

// ReadRuntimeConfig 运行时配置视图。
func (s *AppService) ReadRuntimeConfig() (utils.RuntimeConfigView, error) {
	return adminbiz.RuntimeConfigView()
}

// BroadcastNotification 广播系统通知。
func (s *AppService) BroadcastNotification(ctx context.Context, in *super.AdminBroadcastNotificationReq) (*super.AdminBroadcastNotificationResp, error) {
	created, err := notifybiz.Broadcast(ctx, s.db, in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return &super.AdminBroadcastNotificationResp{NotificationsCreated: created}, nil
}

// SendNotification 向单用户发送系统通知。
func (s *AppService) SendNotification(ctx context.Context, in *super.AdminSendNotificationReq) (*super.AdminSendNotificationResp, error) {
	id, err := notifybiz.SendToUser(ctx, s.db, in.GetUserId(), in.GetTitle(), in.GetContent())
	if err != nil {
		return nil, err
	}
	return &super.AdminSendNotificationResp{NotificationId: strconv.FormatUint(uint64(id), 10)}, nil
}

func (s *AppService) ListAnnouncements(ctx context.Context, in *super.AdminListAnnouncementsReq) (*super.AdminListAnnouncementsResp, error) {
	items, total, err := adminbiz.ListAnnouncements(ctx, s.db, adminbiz.AnnouncementPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(), Status: in.GetStatus(),
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminListAnnouncementsResp{Items: items, Total: total}, nil
}

func (s *AppService) GetAnnouncement(ctx context.Context, in *super.AdminGetAnnouncementReq) (*super.AdminGetAnnouncementResp, error) {
	item, err := adminbiz.GetAnnouncement(ctx, s.db, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return &super.AdminGetAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) ListAuditLogs(ctx context.Context, in *super.AdminListAuditLogsReq) (*super.AdminListAuditLogsResp, error) {
	items, total, err := adminbiz.ListAuditLogs(ctx, s.db, adminbiz.AuditLogFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Action: in.GetAction(),
		Resource: in.GetResource(), AdminID: in.GetAdminId(),
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminListAuditLogsResp{Items: items, Total: total}, nil
}

func (s *AppService) CreateAnnouncement(ctx context.Context, in *super.AdminCreateAnnouncementReq) (*super.AdminCreateAnnouncementResp, error) {
	item, err := adminbiz.CreateAnnouncement(ctx, s.db, in.GetTitle(), in.GetContent(), in.GetCreatedBy())
	if err != nil {
		return nil, err
	}
	return &super.AdminCreateAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) UpdateAnnouncement(ctx context.Context, in *super.AdminUpdateAnnouncementReq) (*super.AdminUpdateAnnouncementResp, error) {
	item, err := adminbiz.UpdateAnnouncement(ctx, s.db, adminbiz.UpdateAnnouncementInput{
		AnnouncementID: in.GetAnnouncementId(),
		Title:          in.GetTitle(),
		Content:        in.GetContent(),
		UpdateTitle:    in.GetUpdateTitle(),
		UpdateContent:  in.GetUpdateContent(),
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminUpdateAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) PublishAnnouncement(ctx context.Context, in *super.AdminPublishAnnouncementReq) (*super.AdminPublishAnnouncementResp, error) {
	item, err := adminbiz.PublishAnnouncement(ctx, s.db, in.GetAnnouncementId())
	if err != nil {
		return nil, err
	}
	return &super.AdminPublishAnnouncementResp{Announcement: item}, nil
}

func (s *AppService) DeleteAnnouncement(ctx context.Context, in *super.AdminDeleteAnnouncementReq) (*super.AdminDeleteAnnouncementResp, error) {
	if err := adminbiz.DeleteAnnouncement(ctx, s.db, in.GetAnnouncementId()); err != nil {
		return nil, err
	}
	return &super.AdminDeleteAnnouncementResp{}, nil
}

func (s *AppService) AdminListGifts(ctx context.Context, in *super.AdminListGiftsReq) (*super.AdminListGiftsResp, error) {
	gifts, total, err := adminbiz.ListGifts(ctx, s.db, adminbiz.GiftPage{
		Page: in.GetPage(), PageSize: in.GetPageSize(),
		Keyword: in.GetKeyword(), Category: in.GetCategory(),
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminListGiftsResp{Gifts: gifts, Total: total}, nil
}

func (s *AppService) AdminGetGift(ctx context.Context, in *super.AdminGetGiftReq) (*super.AdminGetGiftResp, error) {
	gift, err := adminbiz.GetGift(ctx, s.db, in.GetGiftId())
	if err != nil {
		return nil, err
	}
	return &super.AdminGetGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminCreateGift(ctx context.Context, in *super.AdminCreateGiftReq) (*super.AdminCreateGiftResp, error) {
	gift, err := adminbiz.CreateGift(ctx, s.db, in)
	if err != nil {
		return nil, err
	}
	return &super.AdminCreateGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminUpdateGift(ctx context.Context, in *super.AdminUpdateGiftReq) (*super.AdminUpdateGiftResp, error) {
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
	return &super.AdminUpdateGiftResp{Gift: gift}, nil
}

func (s *AppService) AdminDeleteGift(ctx context.Context, in *super.AdminDeleteGiftReq) (*super.AdminDeleteGiftResp, error) {
	if err := adminbiz.DeleteGift(ctx, s.db, in.GetGiftId()); err != nil {
		return nil, err
	}
	return &super.AdminDeleteGiftResp{}, nil
}

func (s *AppService) AdminBootstrapGifts(ctx context.Context, in *super.AdminBootstrapGiftsReq) (*super.AdminBootstrapGiftsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapGifts(ctx, s.db)
	if err != nil {
		return nil, err
	}
	return &super.AdminBootstrapGiftsResp{Created: created}, nil
}
