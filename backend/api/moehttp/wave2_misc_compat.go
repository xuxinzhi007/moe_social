package moehttp

import (
	"errors"
	"fmt"
	"net/http"
	"os"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	contentbiz "backend/internal/biz/content"
	emojibiz "backend/internal/biz/emoji"
	mediabiz "backend/internal/biz/media"
	userbiz "backend/internal/biz/user"
	vipbiz "backend/internal/biz/vip"
	contentapp "backend/internal/service/content"
	chatapp "backend/internal/service/chat"
	mediaapp "backend/internal/service/media"
	adminapp "backend/internal/service/admin"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeWave2MiscCompatRoutes = 27

func RegisterWave2MiscCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")

	if admin := svcCtx.AdminApp; admin != nil {
		r.POST("/api/admin/bootstrap/account", adminBootstrapAccount(admin))
		r.POST("/api/admin/login", adminLogin(admin))
	}

	if user := svcCtx.UserApp; user != nil {
		r.GET("/api/avatar/:user_id", getUserAvatar(user))
		r.PUT("/api/avatar/:user_id", updateUserAvatar(user))
		r.GET("/api/notifications", getNotifications(user))
		r.POST("/api/notifications/:id/read", readNotification(user))
		r.POST("/api/notifications/read-all", readAllNotifications(user))
		r.GET("/api/notifications/unread", getUnreadCount(user))

		r.GET("/api/avatar/outfits", getAvatarOutfits(user))
		r.GET("/api/avatar/outfits/:outfit_id", getAvatarOutfit(user))
		r.POST("/api/avatar/outfits/:outfit_id/purchase", purchaseAvatarOutfit(user))
		r.GET("/api/emoji/packs", getEmojiPacks(user))
		r.GET("/api/emoji/packs/:pack_id", getEmojiPack(user))
		r.POST("/api/emoji/packs/:pack_id/favorite", favoriteEmojiPack(user))
		r.POST("/api/emoji/packs/:pack_id/purchase", purchaseEmojiPack(user))
		r.GET("/api/user/:user_id/emoji/packs", getUserEmojiPacks(user))
	}

	contentApp := contentapp.New()
	r.POST("/api/content/generate", generateContent(contentApp))

	mediaApp := mediaapp.New(mediabiz.ImageConfig{
		LocalDir:      svcCtx.Config.Image.LocalDir,
		PublicBaseURL: svcCtx.Config.Image.PublicBaseUrl,
	})
	r.GET("/api/images", getImageList(mediaApp))
	r.DELETE("/api/images/:filename", deleteImage(mediaApp))
	r.GET("/api/images/:filename", serveImage(mediaApp))
	r.POST("/api/upload", uploadImage(mediaApp))

	chat := svcCtx.ChatApp
	if chat == nil {
		chat = chatapp.New(nil)
	}
	r.POST("/api/notification/broadcast", broadcastNotification(chat))
	r.POST("/api/notification/send", sendNotification(chat))
	r.POST("/api/notification/send-batch", sendBatchNotification(chat))

	if vip := svcCtx.VipAdmin; vip != nil {
		r.POST("/api/vip/plans", createVipPlan(vip))
		r.GET("/api/vip/plans/:plan_id", getVipPlan(vip))
		r.GET("/api/vip/plans", listVipPlans(vip))
	}
}

func adminBootstrapAccount(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rpcResp, err := app.AdminBootstrapAccount(ctx, &moe.AdminBootstrapAccountReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapAccountResp{BaseResp: common.HandleRPCError(err, "")})
		}
		msg := "管理员账号已存在，未创建"
		if rpcResp.GetCreated() > 0 {
			msg = "已创建默认超管，请尽快登录并修改密码"
		}
		return ctx.JSON(http.StatusOK, types.AdminBootstrapAccountResp{
			BaseResp: common.HandleRPCError(nil, msg),
			Data:     types.AdminBootstrapAccountData{Created: int(rpcResp.GetCreated())},
		})
	}
}

func adminLogin(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminLoginReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.AdminLoginResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.AdminLogin(ctx, &moe.AdminLoginReq{
			Username: req.Username,
			Password: req.Password,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminLoginResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminLoginResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminLoginData{
				Token:    rpcResp.Token,
				AdminId:  rpcResp.AdminId,
				Username: rpcResp.Username,
				Role:     rpcResp.Role,
				ExpireAt: rpcResp.ExpireAt,
			},
		})
	}
}

func getUserAvatar(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserAvatarReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserAvatarResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserAvatar(ctx, &moe.GetUserAvatarReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserAvatarResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		if rpcResp.Avatar == nil {
			return ctx.JSON(http.StatusOK, types.GetUserAvatarResp{
				BaseResp: common.HandleError(nil),
				Data:     defaultUserAvatar(req.UserId),
			})
		}
		return ctx.JSON(http.StatusOK, types.GetUserAvatarResp{
			BaseResp: common.HandleError(nil),
			Data:     userAvatarFromRPC(rpcResp.Avatar),
		})
	}
}

func updateUserAvatar(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateUserAvatarReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdateUserAvatarResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdateUserAvatar(ctx, &moe.UpdateUserAvatarReq{
			UserId: req.UserId,
			BaseConfig: &moe.AvatarBaseConfig{
				FaceShape: req.BaseConfig.FaceShape,
				SkinColor: req.BaseConfig.SkinColor,
				EyeType:   req.BaseConfig.EyeType,
				HairStyle: req.BaseConfig.HairStyle,
				HairColor: req.BaseConfig.HairColor,
			},
			CurrentOutfit: &moe.AvatarOutfitConfig{
				Clothes:     req.CurrentOutfit.Clothes,
				Accessories: req.CurrentOutfit.Accessories,
				Background:  req.CurrentOutfit.Background,
			},
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpdateUserAvatarResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		if rpcResp.Avatar == nil {
			return ctx.JSON(http.StatusOK, types.UpdateUserAvatarResp{BaseResp: common.HandleUserGWError(fmt.Errorf("empty avatar"), "")})
		}
		return ctx.JSON(http.StatusOK, types.UpdateUserAvatarResp{
			BaseResp: common.HandleError(nil),
			Data:     userAvatarFromRPC(rpcResp.Avatar),
		})
	}
}

func getNotifications(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetNotificationsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetNotificationsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetNotifications(ctx, &moe.GetNotificationsReq{
			UserId:   req.UserId,
			Page:     int32(req.Page),
			PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetNotificationsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetNotificationsResp{
			BaseResp: common.HandleRPCError(nil, "获取通知列表成功"),
			Data:     notificationsFromRPC(rpcResp.GetNotifications()),
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func readNotification(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ReadNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		_, err := app.ReadNotification(ctx, &moe.ReadNotificationReq{
			Id:     req.Id,
			UserId: req.UserId,
		})
		if err != nil {
			result := common.HandleRPCError(err, "")
			return ctx.JSON(http.StatusOK, result)
		}
		result := common.HandleRPCError(nil, "标记已读成功")
		return ctx.JSON(http.StatusOK, result)
	}
}

func readAllNotifications(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ReadAllNotificationsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		_, err := app.ReadAllNotifications(ctx, &moe.ReadAllNotificationsReq{UserId: req.UserId})
		if err != nil {
			result := common.HandleRPCError(err, "")
			return ctx.JSON(http.StatusOK, result)
		}
		result := common.HandleRPCError(nil, "标记全部已读成功")
		return ctx.JSON(http.StatusOK, result)
	}
}

func getUnreadCount(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUnreadCountReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUnreadCountResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUnreadCount(ctx, &moe.GetUnreadCountReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUnreadCountResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetUnreadCountResp{
			BaseResp: common.HandleRPCError(nil, "获取未读数成功"),
			Data:     int(rpcResp.GetCount()),
		})
	}
}

func createVipPlan(vip *vipadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateVipPlanReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateVipPlanResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		plan, err := vip.CreatePlan(ctx, vipbiz.CreatePlanInput{
			Name:         req.Name,
			Description:  req.Description,
			Price:        req.Price,
			DurationDays: req.DurationDays,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CreateVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.CreateVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "创建VIP套餐成功"),
			Data:     common.VipPlanModelToTypes(plan),
		})
	}
}

func getVipPlan(vip *vipadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetVipPlanReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetVipPlanResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		planID, err := vipbiz.ParsePlanID(req.PlanId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		plan, err := vip.GetPlan(ctx, planID)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetVipPlanResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetVipPlanResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP套餐成功"),
			Data:     common.VipPlanModelToTypes(plan),
		})
	}
}

func listVipPlans(vip *vipadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		rows, err := vip.ListAllPlans(ctx)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetVipPlansResp{BaseResp: common.HandleVipGWError(err, "")})
		}
		respPlans := make([]types.VipPlan, 0, len(rows))
		for _, plan := range rows {
			respPlans = append(respPlans, common.VipPlanModelToTypes(plan))
		}
		return ctx.JSON(http.StatusOK, types.GetVipPlansResp{
			BaseResp: common.HandleRPCError(nil, "获取VIP套餐列表成功"),
			Data:     respPlans,
		})
	}
}

func getAvatarOutfits(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetAvatarOutfitsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetAvatarOutfitsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		result, err := app.ListAvatarOutfits(ctx, userbiz.ListAvatarOutfitsFilter{
			Category: req.Category,
			Style:    req.Style,
			Page:     req.Page,
			PageSize: req.PageSize,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetAvatarOutfitsResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		items := make([]types.AvatarOutfit, 0, len(result.Items))
		for _, item := range result.Items {
			items = append(items, avatarOutfitToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.GetAvatarOutfitsResp{
			BaseResp: common.HandleError(nil),
			Data:     items,
			Total:    result.Total,
		})
	}
}

func getAvatarOutfit(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetAvatarOutfitReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetAvatarOutfitResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		item, err := app.GetAvatarOutfit(ctx, req.OutfitId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetAvatarOutfitResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetAvatarOutfitResp{
			BaseResp: common.HandleError(nil),
			Data:     avatarOutfitToTypes(item),
		})
	}
}

func purchaseAvatarOutfit(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.PurchaseAvatarOutfitReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.PurchaseAvatarOutfitResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		purchaseID, err := app.PurchaseAvatarOutfit(ctx, req.UserId, req.OutfitId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.PurchaseAvatarOutfitResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.PurchaseAvatarOutfitResp{
			BaseResp: common.HandleError(nil),
			Data:     purchaseID,
		})
	}
}

func getEmojiPacks(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetEmojiPacksReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetEmojiPacksResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		result, err := app.ListEmojiPacks(ctx, emojibiz.ListEmojiPacksFilter{
			Category: req.Category,
			Page:     req.Page,
			PageSize: req.PageSize,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetEmojiPacksResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		items := make([]types.EmojiPack, 0, len(result.Items))
		for _, item := range result.Items {
			items = append(items, emojiPackToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.GetEmojiPacksResp{
			BaseResp: common.HandleError(nil),
			Data:     items,
			Total:    result.Total,
		})
	}
}

func getEmojiPack(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetEmojiPackReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetEmojiPackResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		item, err := app.GetEmojiPack(ctx, req.PackId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetEmojiPackResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.GetEmojiPackResp{
			BaseResp: common.HandleError(nil),
			Data:     emojiPackToTypes(item),
		})
	}
}

func favoriteEmojiPack(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FavoriteEmojiPackReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.FavoriteEmojiPackResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		if err := app.FavoriteEmojiPack(ctx, req.UserId, req.PackId); err != nil {
			return ctx.JSON(http.StatusOK, types.FavoriteEmojiPackResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.FavoriteEmojiPackResp{BaseResp: common.HandleError(nil)})
	}
}

func purchaseEmojiPack(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.PurchaseEmojiPackReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.PurchaseEmojiPackResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		purchaseID, err := app.PurchaseEmojiPack(ctx, req.UserId, req.PackId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.PurchaseEmojiPackResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.PurchaseEmojiPackResp{
			BaseResp: common.HandleError(nil),
			Data:     purchaseID,
		})
	}
}

func getUserEmojiPacks(app *userapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserEmojiPacksReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserEmojiPacksResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		items, err := app.ListUserEmojiPacks(ctx, req.UserId)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserEmojiPacksResp{BaseResp: common.HandleUserGWError(err, "")})
		}
		respItems := make([]types.EmojiPack, 0, len(items))
		for _, item := range items {
			respItems = append(respItems, emojiPackToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.GetUserEmojiPacksResp{
			BaseResp: common.HandleError(nil),
			Data:     respItems,
		})
	}
}

func generateContent(app *contentapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ContentGenerationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.ContentGenerationResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		result, err := app.GenerateContent(ctx, contentbiz.GenerateInput{
			UserID:  req.UserId,
			Type:    req.Type,
			Prompt:  req.Prompt,
			Options: req.Options,
		})
		if errors.Is(err, contentbiz.ErrUnsupportedContentType) {
			return ctx.JSON(http.StatusOK, types.ContentGenerationResp{
				BaseResp: types.BaseResp{Code: 400, Message: "不支持的内容类型", Success: false},
			})
		}
		if err != nil {
			return ctx.JSON(http.StatusOK, types.ContentGenerationResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.ContentGenerationResp{
			BaseResp: types.BaseResp{Code: 200, Message: "内容生成成功", Success: true},
			Data: types.ContentGenerationData{
				Id:        result.ID,
				Type:      result.Type,
				Url:       result.URL,
				Content:   result.Content,
				CreatedAt: result.CreatedAt,
			},
		})
	}
}

func getImageList(app *mediaapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		claims, err := mediabiz.ParseClaimsFromRequest(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "unauthorized", Success: false})
		}
		var req types.GetImageListReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetImageListResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
		result, err := app.ListImages(ctx, mediabiz.ListImagesInput{
			UserFolder: userFolder,
			Page:       req.Page,
			PageSize:   req.PageSize,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetImageListResp{BaseResp: common.HandleError(err)})
		}
		items := make([]types.ImageInfo, 0, len(result.Items))
		for _, item := range result.Items {
			items = append(items, imageInfoToTypes(item))
		}
		return ctx.JSON(http.StatusOK, types.GetImageListResp{
			BaseResp: common.HandleError(nil),
			Data:     items,
			Total:    result.Total,
		})
	}
}

func deleteImage(app *mediaapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		claims, err := mediabiz.ParseClaimsFromRequest(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "unauthorized", Success: false})
		}
		var req types.DeleteImageReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.DeleteImageResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
		if err := app.DeleteImage(ctx, userFolder, req.Filename); err != nil {
			if errors.Is(err, os.ErrPermission) {
				return ctx.JSON(http.StatusForbidden, types.DeleteImageResp{
					BaseResp: types.BaseResp{Code: 403, Message: "forbidden", Success: false},
				})
			}
			return ctx.JSON(http.StatusOK, types.DeleteImageResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.DeleteImageResp{BaseResp: common.HandleError(nil)})
	}
}

func serveImage(app *mediaapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeleteImageReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		file, err := app.OpenImage(ctx, req.Filename)
		if err != nil {
			return ctx.JSON(http.StatusNotFound, types.BaseResp{Code: 404, Message: "图片不存在", Success: false})
		}
		f, err := os.Open(file.Path)
		if err != nil {
			return ctx.JSON(http.StatusNotFound, types.BaseResp{Code: 404, Message: "图片不存在", Success: false})
		}
		defer f.Close()

		w := ctx.Response()
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		w.Header().Set("Content-Type", file.ContentType)
		w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%s", file.Filename))
		http.ServeContent(w, ctx.Request(), file.Filename, file.ModTime, f)
		return nil
	}
}

func uploadImage(app *mediaapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		claims, err := mediabiz.ParseClaimsFromRequest(ctx.Request())
		if err != nil {
			return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "unauthorized", Success: false})
		}
		r := ctx.Request()
		if err := r.ParseMultipartForm(100 << 20); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UploadImageResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		file, fileHeader, err := r.FormFile("file")
		if err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UploadImageResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		defer file.Close()

		userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
		info, err := app.UploadImage(ctx, mediabiz.UploadInput{
			UserFolder: userFolder,
			OrigName:   fileHeader.Filename,
			Reader:     file,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UploadImageResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.UploadImageResp{
			BaseResp: common.HandleError(nil),
			Data:     imageInfoToTypes(info),
		})
	}
}

func broadcastNotification(app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.BroadcastNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		_ = app.BroadcastPushNotification(ctx, req.Type, req.Data)
		return ctx.JSON(http.StatusOK, types.BaseResp{Code: 200, Message: "广播成功", Success: true})
	}
}

func sendNotification(app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		if app.PushNotification(ctx, req.UserId, req.Type, req.Data) {
			return ctx.JSON(http.StatusOK, types.BaseResp{Code: 200, Message: "发送成功", Success: true})
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{Code: 404, Message: "用户不在线", Success: false})
	}
}

func sendBatchNotification(app *chatapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SendBatchNotificationReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{Code: -1, Message: err.Error(), Success: false})
		}
		_ = app.PushBatchNotification(ctx, req.UserIDs, req.Type, req.Data)
		return ctx.JSON(http.StatusOK, types.BaseResp{Code: 200, Message: "发送成功", Success: true})
	}
}

func defaultUserAvatar(userID string) types.UserAvatar {
	return types.UserAvatar{
		UserId: userID,
		BaseConfig: types.BaseConfig{
			FaceShape: "face_1",
			SkinColor: "#FDBCB4",
			EyeType:   "eyes_1",
			HairStyle: "hair_1",
			HairColor: "#8B4513",
		},
		CurrentOutfit: types.OutfitConfig{
			Clothes:     "clothes_1",
			Accessories: []string{},
			Background:  "default",
		},
		OwnedOutfits: []string{},
	}
}

func userAvatarFromRPC(a *moe.UserAvatarData) types.UserAvatar {
	avatar := types.UserAvatar{
		UserId:       a.GetUserId(),
		OwnedOutfits: a.GetOwnedOutfits(),
	}
	if bc := a.GetBaseConfig(); bc != nil {
		avatar.BaseConfig = types.BaseConfig{
			FaceShape: bc.GetFaceShape(),
			SkinColor: bc.GetSkinColor(),
			EyeType:   bc.GetEyeType(),
			HairStyle: bc.GetHairStyle(),
			HairColor: bc.GetHairColor(),
		}
	}
	if co := a.GetCurrentOutfit(); co != nil {
		avatar.CurrentOutfit = types.OutfitConfig{
			Clothes:     co.GetClothes(),
			Accessories: co.GetAccessories(),
			Background:  co.GetBackground(),
		}
	}
	return avatar
}

func notificationsFromRPC(items []*moe.Notification) []types.Notification {
	notifications := make([]types.Notification, 0, len(items))
	for _, n := range items {
		notifications = append(notifications, types.Notification{
			Id:           n.GetId(),
			UserId:       n.GetUserId(),
			SenderId:     n.GetSenderId(),
			SenderName:   n.GetSenderName(),
			SenderAvatar: n.GetSenderAvatar(),
			Type:         int(n.GetType()),
			PostId:       n.GetPostId(),
			Content:      n.GetContent(),
			IsRead:       n.GetIsRead(),
			CreatedAt:    n.GetCreatedAt(),
		})
	}
	return notifications
}

func avatarOutfitToTypes(item userbiz.AvatarOutfitItem) types.AvatarOutfit {
	parts := make([]types.OutfitPart, 0, len(item.Parts))
	for _, p := range item.Parts {
		parts = append(parts, types.OutfitPart{Id: p.ID, Type: p.Type, ImageUrl: p.ImageURL})
	}
	return types.AvatarOutfit{
		Id:          item.ID,
		Name:        item.Name,
		Description: item.Description,
		Category:    item.Category,
		Style:       item.Style,
		Price:       item.Price,
		IsFree:      item.IsFree,
		ImageUrl:    item.ImageURL,
		Parts:       parts,
		CreatedAt:   item.CreatedAt,
	}
}

func emojiPackToTypes(item emojibiz.EmojiPackItem) types.EmojiPack {
	emojis := make([]types.Emoji, 0, len(item.Emojis))
	for _, e := range item.Emojis {
		emojis = append(emojis, types.Emoji{
			Id:         e.ID,
			ImageUrl:   e.ImageURL,
			Tags:       e.Tags,
			IsAnimated: e.IsAnimated,
		})
	}
	return types.EmojiPack{
		Id:            item.ID,
		Name:          item.Name,
		Description:   item.Description,
		AuthorName:    item.AuthorName,
		Category:      item.Category,
		Price:         item.Price,
		IsFree:        item.IsFree,
		CoverImage:    item.CoverImage,
		Emojis:        emojis,
		DownloadCount: item.DownloadCount,
	}
}

func imageInfoToTypes(item mediabiz.ImageInfo) types.ImageInfo {
	return types.ImageInfo{
		Id:        item.ID,
		Filename:  item.Filename,
		Url:       item.URL,
		Size:      item.Size,
		CreatedAt: item.CreatedAt,
	}
}
