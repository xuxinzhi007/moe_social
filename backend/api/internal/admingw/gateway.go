package admingw

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/super"
	"backend/utils"

	"google.golang.org/grpc"
)

// Gateway Admin 只读 HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *adminapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *adminapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

// Route 当前路由模式。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) AdminGetGrowthStats(ctx context.Context, in *super.AdminGetGrowthStatsReq, opts ...grpc.CallOption) (*super.AdminGetGrowthStatsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GrowthStats(ctx)
	}
	return g.super.AdminGetGrowthStats(ctx, in, opts...)
}

func (g *Gateway) AdminGetSchemaCatalog(ctx context.Context, in *super.AdminGetSchemaCatalogReq, opts ...grpc.CallOption) (*super.AdminGetSchemaCatalogResp, error) {
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

func (g *Gateway) AdminBroadcastNotification(ctx context.Context, in *super.AdminBroadcastNotificationReq, opts ...grpc.CallOption) (*super.AdminBroadcastNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.BroadcastNotification(ctx, in)
	}
	return g.super.AdminBroadcastNotification(ctx, in, opts...)
}

func (g *Gateway) AdminSendNotification(ctx context.Context, in *super.AdminSendNotificationReq, opts ...grpc.CallOption) (*super.AdminSendNotificationResp, error) {
	if g != nil && g.local != nil {
		return g.local.SendNotification(ctx, in)
	}
	return g.super.AdminSendNotification(ctx, in, opts...)
}

func (g *Gateway) AdminListAnnouncements(ctx context.Context, in *super.AdminListAnnouncementsReq, opts ...grpc.CallOption) (*super.AdminListAnnouncementsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAnnouncements(ctx, in)
	}
	return g.super.AdminListAnnouncements(ctx, in, opts...)
}

func (g *Gateway) AdminGetAnnouncement(ctx context.Context, in *super.AdminGetAnnouncementReq, opts ...grpc.CallOption) (*super.AdminGetAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetAnnouncement(ctx, in)
	}
	return g.super.AdminGetAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListAuditLogs(ctx context.Context, in *super.AdminListAuditLogsReq, opts ...grpc.CallOption) (*super.AdminListAuditLogsResp, error) {
	if g != nil && g.local != nil {
		return g.local.ListAuditLogs(ctx, in)
	}
	return g.super.AdminListAuditLogs(ctx, in, opts...)
}

func (g *Gateway) AdminCreateAnnouncement(ctx context.Context, in *super.AdminCreateAnnouncementReq, opts ...grpc.CallOption) (*super.AdminCreateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateAnnouncement(ctx, in)
	}
	return g.super.AdminCreateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateAnnouncement(ctx context.Context, in *super.AdminUpdateAnnouncementReq, opts ...grpc.CallOption) (*super.AdminUpdateAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdateAnnouncement(ctx, in)
	}
	return g.super.AdminUpdateAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminPublishAnnouncement(ctx context.Context, in *super.AdminPublishAnnouncementReq, opts ...grpc.CallOption) (*super.AdminPublishAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.PublishAnnouncement(ctx, in)
	}
	return g.super.AdminPublishAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteAnnouncement(ctx context.Context, in *super.AdminDeleteAnnouncementReq, opts ...grpc.CallOption) (*super.AdminDeleteAnnouncementResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeleteAnnouncement(ctx, in)
	}
	return g.super.AdminDeleteAnnouncement(ctx, in, opts...)
}

func (g *Gateway) AdminListGifts(ctx context.Context, in *super.AdminListGiftsReq, opts ...grpc.CallOption) (*super.AdminListGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminListGifts(ctx, in)
	}
	return g.super.AdminListGifts(ctx, in, opts...)
}

func (g *Gateway) AdminGetGift(ctx context.Context, in *super.AdminGetGiftReq, opts ...grpc.CallOption) (*super.AdminGetGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminGetGift(ctx, in)
	}
	return g.super.AdminGetGift(ctx, in, opts...)
}

func (g *Gateway) AdminCreateGift(ctx context.Context, in *super.AdminCreateGiftReq, opts ...grpc.CallOption) (*super.AdminCreateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminCreateGift(ctx, in)
	}
	return g.super.AdminCreateGift(ctx, in, opts...)
}

func (g *Gateway) AdminUpdateGift(ctx context.Context, in *super.AdminUpdateGiftReq, opts ...grpc.CallOption) (*super.AdminUpdateGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminUpdateGift(ctx, in)
	}
	return g.super.AdminUpdateGift(ctx, in, opts...)
}

func (g *Gateway) AdminDeleteGift(ctx context.Context, in *super.AdminDeleteGiftReq, opts ...grpc.CallOption) (*super.AdminDeleteGiftResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminDeleteGift(ctx, in)
	}
	return g.super.AdminDeleteGift(ctx, in, opts...)
}

func (g *Gateway) AdminBootstrapGifts(ctx context.Context, in *super.AdminBootstrapGiftsReq, opts ...grpc.CallOption) (*super.AdminBootstrapGiftsResp, error) {
	if g != nil && g.local != nil {
		return g.local.AdminBootstrapGifts(ctx, in)
	}
	return g.super.AdminBootstrapGifts(ctx, in, opts...)
}
