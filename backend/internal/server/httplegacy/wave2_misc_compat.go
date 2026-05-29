package httplegacy

import (
	"errors"
	"fmt"
	"net/http"
	"os"

	"backend/internal/apilegacy/common"
	mediabiz "backend/internal/biz/media"
	"backend/internal/legacy/types"
	"backend/internal/platform/svc"
	mediaapp "backend/internal/service/media"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeWave2MiscCompatRoutes 图片上传/静态服务（multipart，暂留 compat）。
const PilotNativeWave2MiscCompatRoutes = 4

// RegisterWave2MiscCompat P1：admin/login、avatar/emoji、content、notification、vip plans 已迁入 proto HTTP。
func RegisterWave2MiscCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")

	mediaApp := mediaapp.New(mediabiz.ImageConfig{
		LocalDir:      svcCtx.Config.Image.LocalDir,
		PublicBaseURL: svcCtx.Config.Image.PublicBaseUrl,
	})
	r.GET("/api/images", getImageList(mediaApp))
	r.DELETE("/api/images/:filename", deleteImage(mediaApp))
	r.GET("/api/images/:filename", serveImage(mediaApp))
	r.POST("/api/upload", uploadImage(mediaApp))
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

func imageInfoToTypes(item mediabiz.ImageInfo) types.ImageInfo {
	return types.ImageInfo{
		Id:        item.ID,
		Filename:  item.Filename,
		Url:       item.URL,
		Size:      item.Size,
		CreatedAt: item.CreatedAt,
	}
}
