package mediahttp

import (
	"context"

	mediav1 "backend/api/media/v1"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterHTTPServer 注册 media HTTP（multipart 上传与二进制图片走自定义 handler）。
func RegisterHTTPServer(s *khttp.Server, srv *Server) {
	if s == nil || srv == nil {
		return
	}
	r := s.Route("/")
	r.GET("/api/images", _Media_ListImages_HTTP_Handler(srv))
	r.DELETE("/api/images/{filename}", _Media_DeleteImage_HTTP_Handler(srv))
	r.POST("/api/upload", _Media_UploadImage_HTTP_Handler(srv))
	r.GET("/api/images/{filename}", srv.ServeImageHTTP)
}

func _Media_ListImages_HTTP_Handler(srv mediav1.MediaHTTPServer) func(ctx khttp.Context) error {
	return func(ctx khttp.Context) error {
		var in mediav1.ListImagesRequest
		if err := ctx.BindQuery(&in); err != nil {
			return err
		}
		khttp.SetOperation(ctx, mediav1.OperationMediaListImages)
		h := ctx.Middleware(func(ctx context.Context, req interface{}) (interface{}, error) {
			return srv.ListImages(ctx, req.(*mediav1.ListImagesRequest))
		})
		out, err := h(ctx, &in)
		if err != nil {
			return err
		}
		return ctx.Result(200, out.(*mediav1.ListImagesReply))
	}
}

func _Media_DeleteImage_HTTP_Handler(srv mediav1.MediaHTTPServer) func(ctx khttp.Context) error {
	return func(ctx khttp.Context) error {
		var in mediav1.DeleteImageRequest
		if err := ctx.BindVars(&in); err != nil {
			return err
		}
		if err := ctx.BindQuery(&in); err != nil {
			return err
		}
		khttp.SetOperation(ctx, mediav1.OperationMediaDeleteImage)
		h := ctx.Middleware(func(ctx context.Context, req interface{}) (interface{}, error) {
			return srv.DeleteImage(ctx, req.(*mediav1.DeleteImageRequest))
		})
		out, err := h(ctx, &in)
		if err != nil {
			return err
		}
		return ctx.Result(200, out.(*mediav1.DeleteImageReply))
	}
}

func _Media_UploadImage_HTTP_Handler(srv mediav1.MediaHTTPServer) func(ctx khttp.Context) error {
	return func(ctx khttp.Context) error {
		var in mediav1.UploadImageRequest
		khttp.SetOperation(ctx, mediav1.OperationMediaUploadImage)
		h := ctx.Middleware(func(ctx context.Context, req interface{}) (interface{}, error) {
			return srv.UploadImage(ctx, req.(*mediav1.UploadImageRequest))
		})
		out, err := h(ctx, &in)
		if err != nil {
			return err
		}
		return ctx.Result(200, out.(*mediav1.UploadImageReply))
	}
}
