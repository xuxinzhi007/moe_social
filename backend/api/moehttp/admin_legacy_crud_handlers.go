package moehttp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	adminbiz "backend/internal/biz/admin"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func legacyAdminActx(ctx khttp.Context) (context.Context, *types.BaseResp) {
	claims, br := common.RequireAdminToken(ctx.Request())
	if br != nil {
		return ctx, br
	}
	return common.WithAdminActor(ctx, claims, common.ClientIP(ctx.Request())), nil
}

func adminLegacyUpdateAiAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAiAgentResp{BaseResp: *br})
		}
		var req types.AdminUpdateAiAgentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		uid := strings.TrimSpace(req.UserId)
		aid := strings.TrimSpace(req.AgentId)
		payload := strings.TrimSpace(req.PayloadJson)
		if uid == "" || aid == "" || payload == "" {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAiAgentResp{
				BaseResp: types.BaseResp{Success: false, Message: "user_id、agent_id、payload_json 均不能为空"},
			})
		}
		if !json.Valid([]byte(payload)) {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAiAgentResp{
				BaseResp: types.BaseResp{Success: false, Message: "payload_json 不是合法 JSON"},
			})
		}
		if svcCtx.AIApp == nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAiAgentResp{
				BaseResp: types.BaseResp{Success: false, Message: "AI 网关未就绪"},
			})
		}
		_, err := svcCtx.AIApp.UpsertAiAgent(actx, &moe.UpsertAiResourceReq{
			UserId:      uid,
			Id:          aid,
			PayloadJson: payload,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateAiAgentResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpdateAiAgentResp{BaseResp: common.HandleError(nil)}
		resp.BaseResp.Message = "保存成功"
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "update", "ai_agent", aid, "管理台更新酒馆角色卡")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyMe() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		claims, br := common.RequireAdminToken(ctx.Request())
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminMeResp{BaseResp: *br})
		}
		return ctx.JSON(http.StatusOK, types.AdminMeResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.AdminMeData{
				AdminId:  uint64(claims.AdminID),
				Username: claims.Username,
				Role:     claims.Role,
			},
		})
	}
}

func adminLegacyListMediaImages(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMediaImagesResp{BaseResp: *br})
		}
		var req types.AdminListMediaImagesReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		publicBase := utils.ResolveMediaPublicBase(
			ctx.Request(),
			svcCtx.Config.Image.PublicBaseUrl,
			svcCtx.Config.ClientPublicApiBaseUrl,
		)
		rows, owners, total, err := utils.ListAdminMediaImages(
			svcCtx.Config.Image.LocalDir,
			publicBase,
			req.Page,
			req.PageSize,
			req.Keyword,
			req.OwnerFolder,
			req.MediaKind,
		)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMediaImagesResp{BaseResp: common.HandleError(err)})
		}
		items := make([]types.AdminMediaImageItem, len(rows))
		for i, row := range rows {
			items[i] = types.AdminMediaImageItem{
				Filename:    row.Filename,
				FileName:    row.FileName,
				OwnerFolder: row.OwnerFolder,
				MediaKind:   row.MediaKind,
				Url:         row.URL,
				Size:        row.Size,
				CreatedAt:   row.CreatedAt,
				OwnerHint:   row.OwnerHint,
			}
		}
		ownerItems := make([]types.AdminMediaOwnerSummary, len(owners))
		for i, o := range owners {
			ownerItems[i] = types.AdminMediaOwnerSummary{
				OwnerFolder:  o.OwnerFolder,
				UserId:       o.UserID,
				UsernameHint: o.UsernameHint,
				FileCount:    o.FileCount,
				TotalBytes:   o.TotalBytes,
			}
		}
		return ctx.JSON(http.StatusOK, types.AdminListMediaImagesResp{
			BaseResp: common.HandleError(nil),
			Data: types.AdminListMediaImagesData{
				Items:  items,
				Total:  total,
				Owners: ownerItems,
			},
		})
	}
}

func adminLegacyDeleteMediaImage(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMediaImageResp{BaseResp: *br})
		}
		var req types.AdminDeleteMediaImageReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if err := utils.DeleteAdminMediaImage(svcCtx.Config.Image.LocalDir, req.Filename); err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMediaImageResp{BaseResp: common.HandleError(err)})
		}
		resp := types.AdminDeleteMediaImageResp{BaseResp: common.HandleError(nil)}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "delete", "media_image", req.Filename, "删除云图库文件")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyListMemories(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMemoriesResp{BaseResp: *br})
		}
		var req types.AdminListMemoriesReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.ListMemories(ctx, &moe.AdminListMemoriesReq{
			Page:       int32(req.Page),
			PageSize:   int32(req.PageSize),
			UserId:     req.UserId,
			Keyword:    req.Keyword,
			MemoryType: req.MemoryType,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMemoriesResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminMemoryItem, len(rpcResp.GetItems()))
		for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminMemoryToTypes(item)
		}
		return ctx.JSON(http.StatusOK, types.AdminListMemoriesResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     types.AdminListMemoriesData{Items: items, Total: int(rpcResp.GetTotal())},
		})
	}
}

func adminLegacyDeleteMemory(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMemoryResp{BaseResp: *br})
		}
		var req types.AdminDeleteMemoryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := app.DeleteMemory(actx, &moe.AdminDeleteMemoryReq{MemoryId: req.MemoryId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(nil, "ok")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "delete", "user_memory", fmt.Sprintf("%d", req.MemoryId), "删除用户记忆")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyGetMemoryStats(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMemoryStatsResp{BaseResp: *br})
		}
		rpcResp, err := app.GetMemoryStats(ctx, &moe.AdminGetMemoryStatsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMemoryStatsResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMemoryStatsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminMemoryStatsToTypes(rpcResp.GetStats()),
		})
	}
}

func adminLegacyListMenus(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMenusResp{BaseResp: *br})
		}
		rpcResp, err := app.ListMenus(ctx, &moe.AdminListMenusReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMenusResp{BaseResp: common.HandleRPCError(err, "")})
		}
		items := make([]types.AdminMenuItem, len(rpcResp.GetItems()))
		for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminMenuToTypes(item)
		}
		return ctx.JSON(http.StatusOK, types.AdminListMenusResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
		})
	}
}

func adminLegacyUpsertMenu(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpsertMenuResp{BaseResp: *br})
		}
		var req types.AdminUpsertMenuReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.UpsertMenu(actx, &moe.AdminUpsertMenuReq{
			Key:          req.Key,
			Kind:         req.Kind,
			ParentKey:    req.ParentKey,
			Path:         req.Path,
			Label:        req.Label,
			Icon:         req.Icon,
			Caption:      req.Caption,
			Status:       req.Status,
			AppDomain:    req.AppDomain,
			SortOrder:    int32(req.SortOrder),
			DefaultOpen:  req.DefaultOpen,
			End:          req.End,
			ExternalHref: req.ExternalHref,
			Enabled:      req.Enabled,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpsertMenuResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminUpsertMenuResp{
			BaseResp: common.HandleRPCError(nil, "保存成功"),
			Data:     common.RpcAdminMenuToTypes(rpcResp.GetMenu()),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "upsert", "admin_menu", req.Key, "保存侧栏菜单")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyDeleteMenu(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMenuResp{BaseResp: *br})
		}
		var req types.AdminDeleteMenuReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		_, err := app.DeleteMenu(actx, &moe.AdminDeleteMenuReq{MenuKey: req.MenuKey})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminDeleteMenuResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "delete", "admin_menu", req.MenuKey, "删除侧栏菜单")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyBootstrapMenus(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapMenusResp{BaseResp: *br})
		}
		rpcResp, err := app.BootstrapMenus(actx, &moe.AdminBootstrapMenusReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminBootstrapMenusResp{BaseResp: common.HandleRPCError(err, "")})
		}
		resp := types.AdminBootstrapMenusResp{
			BaseResp: common.HandleRPCError(nil, "初始化成功"),
			Data:     types.AdminBootstrapMenusData{Created: int(rpcResp.GetCreated())},
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "bootstrap", "admin_menu", "", "导入默认侧栏菜单")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyGetRuntimeConfig(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminRuntimeConfigResp{BaseResp: *br})
		}
		view, err := app.ReadRuntimeConfig()
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminRuntimeConfigResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminRuntimeConfigResp{
			BaseResp: common.HandleError(nil),
			Data:     legacyRuntimeConfigToTypes(view, svcCtx),
		})
	}
}

func adminLegacyUpdateRuntimeConfig(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		actx, br := legacyAdminActx(ctx)
		if br != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateRuntimeConfigResp{BaseResp: *br})
		}
		var req types.AdminUpdateRuntimeConfigReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		patch := utils.RuntimeConfigPatch{}
		if req.UpdatePublicApiBaseUrl {
			v := req.PublicApiBaseUrl
			patch.PublicApiBaseUrl = &v
		}
		if req.UpdateApiPublicBaseUrl {
			v := req.ApiPublicBaseUrl
			patch.ApiPublicBaseUrl = &v
		}
		if req.UpdateImagePublicBaseUrl {
			v := req.ImagePublicBaseUrl
			patch.ImagePublicBaseUrl = &v
		}
		if req.UpdateImageLocalDir {
			v := req.ImageLocalDir
			patch.ImageLocalDir = &v
		}
		if req.UpdateImageMaxBytes {
			v := req.ImageMaxBytes
			patch.ImageMaxBytes = &v
		}
		view, err := utils.ApplyRuntimeConfigPatch(patch)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateRuntimeConfigResp{BaseResp: common.HandleError(err)})
		}
		if patch.PublicApiBaseUrl != nil {
			svcCtx.Config.ClientPublicApiBaseUrl = view.PublicApiBaseUrl
		}
		if patch.ImagePublicBaseUrl != nil {
			svcCtx.Config.Image.PublicBaseUrl = view.ImagePublicBaseUrl
		}
		if patch.ImageLocalDir != nil {
			svcCtx.Config.Image.LocalDir = view.ImageLocalDir
		}
		if patch.ImageMaxBytes != nil {
			svcCtx.Config.Image.MaxBytes = view.ImageMaxBytes
		}
		resp := types.AdminUpdateRuntimeConfigResp{
			BaseResp: common.HandleError(nil),
			Data:     legacyRuntimeConfigToTypes(view, svcCtx),
		}
		if resp.BaseResp.Success {
			common.TryRecordAdminAudit(actx, svcCtx, "update", "runtime_config", "", "更新运行时配置")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

func adminLegacyRuntimeOverview(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := legacyAdminActx(ctx); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminRuntimeOverviewResp{BaseResp: *br})
		}
		data, err := app.RuntimeOverview(ctx)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminRuntimeOverviewResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminRuntimeOverviewResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     legacyRuntimeOverviewToTypes(data),
		})
	}
}

func legacyRuntimeConfigToTypes(view utils.RuntimeConfigView, svcCtx *svc.ServiceContext) types.AdminRuntimeConfigData {
	data := types.AdminRuntimeConfigData{
		PublicApiBaseUrl:   view.PublicApiBaseUrl,
		ApiPublicBaseUrl:   view.ApiPublicBaseUrl,
		ImagePublicBaseUrl: view.ImagePublicBaseUrl,
		ImageLocalDir:      view.ImageLocalDir,
		ImageMaxBytes:      view.ImageMaxBytes,
		ConfigFile:         view.ConfigFile,
		RequiresRestart:    false,
	}
	if data.PublicApiBaseUrl == "" {
		data.PublicApiBaseUrl = svcCtx.Config.ClientPublicApiBaseUrl
	}
	if data.ImagePublicBaseUrl == "" {
		data.ImagePublicBaseUrl = svcCtx.Config.Image.PublicBaseUrl
	}
	if data.ImageLocalDir == "" {
		data.ImageLocalDir = svcCtx.Config.Image.LocalDir
	}
	if data.ImageMaxBytes == 0 {
		data.ImageMaxBytes = svcCtx.Config.Image.MaxBytes
	}
	return data
}

func legacyRuntimeOverviewToTypes(data *adminbiz.RuntimeOverviewResult) types.AdminRuntimeOverviewData {
	if data == nil {
		return types.AdminRuntimeOverviewData{}
	}
	return types.AdminRuntimeOverviewData{
		ApiProcess:       legacyRuntimeProcessToTypes(data.ApiProcess),
		RpcProcess:       legacyRuntimeProcessToTypes(data.RpcProcess),
		RpcMonitorOnline: data.RpcMonitorOnline,
		Layout:           data.Layout,
		ProcessesNote:    data.ProcessesNote,
		EstimatedRssMb:   data.EstimatedRssMb,
	}
}

func legacyRuntimeProcessToTypes(p adminbiz.RuntimeProcessInfo) types.AdminRuntimeProcessInfo {
	return types.AdminRuntimeProcessInfo{
		Role:        p.Role,
		Pid:         p.Pid,
		GoAllocMb:   p.GoAllocMb,
		GoSysMb:     p.GoSysMb,
		RssMb:       p.RssMb,
		Goroutines:  p.Goroutines,
		NumCpu:      p.NumCpu,
		Reachable:   p.Reachable,
		SameProcess: p.SameProcess,
	}
}
