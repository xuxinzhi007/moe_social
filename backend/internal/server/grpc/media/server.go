package mediagrpc

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"

	mediav1 "backend/api/media/v1"
	mediabiz "backend/internal/biz/media"
	mediaapp "backend/internal/service/media"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/genproto/googleapis/api/httpbody"
)

// Server 实现 media.v1.Media gRPC/HTTP。
type Server struct {
	mediav1.UnimplementedMediaServer
	app *mediaapp.AppService
}

// New 构造 Media gRPC 服务。
func New(app *mediaapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*mediaapp.AppService, error) {
	if s.app == nil {
		return nil, errMediaAppNil
	}
	return s.app, nil
}

func (s *Server) ListImages(ctx context.Context, in *mediav1.ListImagesRequest) (*mediav1.ListImagesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claims, err := claimsFromContext(ctx)
	if err != nil {
		return nil, err
	}
	userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
	result, err := app.ListImages(ctx, mediabiz.ListImagesInput{
		UserFolder: userFolder,
		Page:       int(in.GetPage()),
		PageSize:   int(in.GetPageSize()),
	})
	if err != nil {
		return nil, err
	}
	images := make([]*mediav1.ImageInfo, 0, len(result.Items))
	for _, item := range result.Items {
		images = append(images, imageInfoToProto(item))
	}
	return &mediav1.ListImagesReply{
		Images: images,
		Total:  int32(result.Total),
	}, nil
}

func (s *Server) DeleteImage(ctx context.Context, in *mediav1.DeleteImageRequest) (*mediav1.DeleteImageReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	claims, err := claimsFromContext(ctx)
	if err != nil {
		return nil, err
	}
	userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
	if err := app.DeleteImage(ctx, userFolder, in.GetFilename()); err != nil {
		if errors.Is(err, os.ErrPermission) {
			return nil, errForbidden
		}
		return nil, err
	}
	return &mediav1.DeleteImageReply{}, nil
}

func (s *Server) UploadImage(ctx context.Context, _ *mediav1.UploadImageRequest) (*mediav1.UploadImageReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, errUnauthorized
	}
	claims, err := claimsFromRequest(req)
	if err != nil {
		return nil, err
	}
	if err := req.ParseMultipartForm(100 << 20); err != nil {
		return nil, err
	}
	file, fileHeader, err := req.FormFile("file")
	if err != nil {
		return nil, err
	}
	defer file.Close()

	userFolder := mediabiz.FolderNameForUser(claims.UserID, claims.Username)
	info, err := app.UploadImage(ctx, mediabiz.UploadInput{
		UserFolder: userFolder,
		OrigName:   fileHeader.Filename,
		Reader:     file,
	})
	if err != nil {
		return nil, err
	}
	return uploadReplyFromInfo(info), nil
}

func (s *Server) ServeImage(ctx context.Context, in *mediav1.ServeImageRequest) (*httpbody.HttpBody, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	file, err := app.OpenImage(ctx, in.GetFilename())
	if err != nil {
		return nil, errNotFound
	}
	f, err := os.Open(file.Path)
	if err != nil {
		return nil, errNotFound
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}
	return &httpbody.HttpBody{
		ContentType: file.ContentType,
		Data:        data,
	}, nil
}

// ServeImageHTTP 流式输出图片（跳过 JSON 信封）。
func (s *Server) ServeImageHTTP(ctx khttp.Context) error {
	app, err := s.requireApp()
	if err != nil {
		return err
	}
	filename := ctx.Vars().Get("filename")
	if filename == "" {
		return writeImageError(ctx, http.StatusBadRequest, -1, "invalid filename")
	}
	file, err := app.OpenImage(ctx, filename)
	if err != nil {
		return writeImageError(ctx, http.StatusNotFound, 404, "图片不存在")
	}
	f, err := os.Open(file.Path)
	if err != nil {
		return writeImageError(ctx, http.StatusNotFound, 404, "图片不存在")
	}
	defer f.Close()

	w := ctx.Response()
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.Header().Set("Content-Type", file.ContentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%s", file.Filename))
	http.ServeContent(w, ctx.Request(), file.Filename, file.ModTime, f)
	return nil
}

func writeImageError(ctx khttp.Context, status, code int, message string) error {
	return ctx.JSON(status, map[string]any{
		"code":    code,
		"message": message,
		"success": false,
	})
}

func imageInfoToProto(item mediabiz.ImageInfo) *mediav1.ImageInfo {
	return &mediav1.ImageInfo{
		Id:        item.ID,
		Filename:  item.Filename,
		Url:       item.URL,
		Size:      item.Size,
		CreatedAt: item.CreatedAt,
	}
}

func uploadReplyFromInfo(item mediabiz.ImageInfo) *mediav1.UploadImageReply {
	return &mediav1.UploadImageReply{
		Id:        item.ID,
		Filename:  item.Filename,
		Url:       item.URL,
		Size:      item.Size,
		CreatedAt: item.CreatedAt,
	}
}
