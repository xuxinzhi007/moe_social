package moehttp

import (
	"context"

	adminpubliclogic "backend/api/internal/logic/admin_public"
	avatarlogic "backend/api/internal/logic/avatar"
	contentlogic "backend/api/internal/logic/content"
	emojiLogic "backend/api/internal/logic/emoji"
	imagelogic "backend/api/internal/logic/image"
	notificationlogic "backend/api/internal/logic/notification"
	viplogic "backend/api/internal/logic/vip"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeWave2MiscCompatRoutes = 27

func RegisterWave2MiscCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/admin/bootstrap/account", hadminpublicAdminBootstrapAccount(svcCtx))
	r.POST("/api/admin/login", hadminpublicAdminLogin(svcCtx))
	r.GET("/api/avatar/:user_id", havatarGetUserAvatar(svcCtx))
	r.PUT("/api/avatar/:user_id", havatarUpdateUserAvatar(svcCtx))
	r.GET("/api/avatar/outfits", havatarGetAvatarOutfits(svcCtx))
	r.GET("/api/avatar/outfits/:outfit_id", havatarGetAvatarOutfit(svcCtx))
	r.POST("/api/avatar/outfits/:outfit_id/purchase", havatarPurchaseAvatarOutfit(svcCtx))
	r.POST("/api/content/generate", hcontentGenerateContent(svcCtx))
	r.GET("/api/emoji/packs", hemojiGetEmojiPacks(svcCtx))
	r.GET("/api/emoji/packs/:pack_id", hemojiGetEmojiPack(svcCtx))
	r.POST("/api/emoji/packs/:pack_id/favorite", hemojiFavoriteEmojiPack(svcCtx))
	r.POST("/api/emoji/packs/:pack_id/purchase", hemojiPurchaseEmojiPack(svcCtx))
	r.GET("/api/user/:user_id/emoji/packs", hemojiGetUserEmojiPacks(svcCtx))
	r.GET("/api/images", himageGetImageList(svcCtx))
	r.DELETE("/api/images/:filename", himageDeleteImage(svcCtx))
	r.GET("/api/images/:filename", himageGetImage(svcCtx))
	r.POST("/api/upload", himageUploadImage(svcCtx))
	r.POST("/api/notification/broadcast", hnotificationBroadcastNotification(svcCtx))
	r.POST("/api/notification/send", hnotificationSendNotification(svcCtx))
	r.POST("/api/notification/send-batch", hnotificationSendBatchNotification(svcCtx))
	r.GET("/api/notifications", hnotificationGetNotifications(svcCtx))
	r.POST("/api/notifications/:id/read", hnotificationReadNotification(svcCtx))
	r.POST("/api/notifications/read-all", hnotificationReadAllNotifications(svcCtx))
	r.GET("/api/notifications/unread", hnotificationGetUnreadCount(svcCtx))
	r.GET("/api/vip/plans", hvipGetVipPlans(svcCtx))
	r.POST("/api/vip/plans", hvipCreateVipPlan(svcCtx))
	r.GET("/api/vip/plans/:plan_id", hvipGetVipPlan(svcCtx))
}

func hadminpublicAdminBootstrapAccount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := adminpubliclogic.NewAdminBootstrapAccountLogic(ctx, svcCtx)
		return l.AdminBootstrapAccount(req)
	})
}

func hadminpublicAdminLogin(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.AdminLoginReq) (any, error) {
		l := adminpubliclogic.NewAdminLoginLogic(ctx, svcCtx)
		return l.AdminLogin(req)
	})
}

func havatarGetUserAvatar(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetUserAvatarReq) (any, error) {
		l := avatarlogic.NewGetUserAvatarLogic(ctx, svcCtx)
		return l.GetUserAvatar(req)
	})
}

func havatarUpdateUserAvatar(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.UpdateUserAvatarReq) (any, error) {
		l := avatarlogic.NewUpdateUserAvatarLogic(ctx, svcCtx)
		return l.UpdateUserAvatar(req)
	})
}

func havatarGetAvatarOutfits(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetAvatarOutfitsReq) (any, error) {
		l := avatarlogic.NewGetAvatarOutfitsLogic(ctx, svcCtx)
		return l.GetAvatarOutfits(req)
	})
}

func havatarGetAvatarOutfit(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetAvatarOutfitReq) (any, error) {
		l := avatarlogic.NewGetAvatarOutfitLogic(ctx, svcCtx)
		return l.GetAvatarOutfit(req)
	})
}

func havatarPurchaseAvatarOutfit(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.PurchaseAvatarOutfitReq) (any, error) {
		l := avatarlogic.NewPurchaseAvatarOutfitLogic(ctx, svcCtx)
		return l.PurchaseAvatarOutfit(req)
	})
}

func hcontentGenerateContent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ContentGenerationReq) (any, error) {
		l := contentlogic.NewGenerateContentLogic(ctx, svcCtx)
		return l.GenerateContent(req)
	})
}

func hemojiGetEmojiPacks(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetEmojiPacksReq) (any, error) {
		l := emojiLogic.NewGetEmojiPacksLogic(ctx, svcCtx)
		return l.GetEmojiPacks(req)
	})
}

func hemojiGetEmojiPack(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetEmojiPackReq) (any, error) {
		l := emojiLogic.NewGetEmojiPackLogic(ctx, svcCtx)
		return l.GetEmojiPack(req)
	})
}

func hemojiFavoriteEmojiPack(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.FavoriteEmojiPackReq) (any, error) {
		l := emojiLogic.NewFavoriteEmojiPackLogic(ctx, svcCtx)
		return l.FavoriteEmojiPack(req)
	})
}

func hemojiPurchaseEmojiPack(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.PurchaseEmojiPackReq) (any, error) {
		l := emojiLogic.NewPurchaseEmojiPackLogic(ctx, svcCtx)
		return l.PurchaseEmojiPack(req)
	})
}

func hemojiGetUserEmojiPacks(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetUserEmojiPacksReq) (any, error) {
		l := emojiLogic.NewGetUserEmojiPacksLogic(ctx, svcCtx)
		return l.GetUserEmojiPacks(req)
	})
}

func himageGetImageList(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetImageListReq) (any, error) {
		l := imagelogic.NewGetImageListLogic(ctx, svcCtx)
		return l.GetImageList(req)
	})
}

func himageDeleteImage(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.DeleteImageReq) (any, error) {
		l := imagelogic.NewDeleteImageLogic(ctx, svcCtx)
		return l.DeleteImage(req)
	})
}

func himageGetImage(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.DeleteImageReq) (any, error) {
		l := imagelogic.NewGetImageLogic(ctx, svcCtx)
		return l.GetImage(req)
	})
}

func himageUploadImage(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.UploadImageReq) (any, error) {
		l := imagelogic.NewUploadImageLogic(ctx, svcCtx)
		return l.UploadImage(req)
	})
}

func hnotificationBroadcastNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.BroadcastNotificationReq) (any, error) {
		l := notificationlogic.NewBroadcastNotificationLogic(ctx, svcCtx)
		return l.BroadcastNotification(req)
	})
}

func hnotificationSendNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.SendNotificationReq) (any, error) {
		l := notificationlogic.NewSendNotificationLogic(ctx, svcCtx)
		return l.SendNotification(req)
	})
}

func hnotificationSendBatchNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.SendBatchNotificationReq) (any, error) {
		l := notificationlogic.NewSendBatchNotificationLogic(ctx, svcCtx)
		return l.SendBatchNotification(req)
	})
}

func hnotificationGetNotifications(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetNotificationsReq) (any, error) {
		l := notificationlogic.NewGetNotificationsLogic(ctx, svcCtx)
		return l.GetNotifications(req)
	})
}

func hnotificationReadNotification(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ReadNotificationReq) (any, error) {
		l := notificationlogic.NewReadNotificationLogic(ctx, svcCtx)
		return l.ReadNotification(req)
	})
}

func hnotificationReadAllNotifications(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.ReadAllNotificationsReq) (any, error) {
		l := notificationlogic.NewReadAllNotificationsLogic(ctx, svcCtx)
		return l.ReadAllNotifications(req)
	})
}

func hnotificationGetUnreadCount(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetUnreadCountReq) (any, error) {
		l := notificationlogic.NewGetUnreadCountLogic(ctx, svcCtx)
		return l.GetUnreadCount(req)
	})
}

func hvipGetVipPlans(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := viplogic.NewGetVipPlansLogic(ctx, svcCtx)
		return l.GetVipPlans(req)
	})
}

func hvipCreateVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.CreateVipPlanReq) (any, error) {
		l := viplogic.NewCreateVipPlanLogic(ctx, svcCtx)
		return l.CreateVipPlan(req)
	})
}

func hvipGetVipPlan(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.GetVipPlanReq) (any, error) {
		l := viplogic.NewGetVipPlanLogic(ctx, svcCtx)
		return l.GetVipPlan(req)
	})
}
