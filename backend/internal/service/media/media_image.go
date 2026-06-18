package mediaapp

import (
	"context"
	mediabiz "backend/internal/biz/media"
)

// ListImages 列出用户图片。
func (s *AppService) ListImages(ctx context.Context, in mediabiz.ListImagesInput) (mediabiz.ListImagesResult, error) {
	return mediabiz.ListImages(ctx, s.cfg, in)
}

// DeleteImage 删除用户图片。
func (s *AppService) DeleteImage(ctx context.Context, userFolder, key string) error {
	return mediabiz.DeleteImage(ctx, s.cfg, userFolder, key)
}

// OpenImage 打开图片文件。
func (s *AppService) OpenImage(ctx context.Context, key string) (mediabiz.ImageFile, error) {
	return mediabiz.OpenImage(ctx, s.cfg, key)
}

// UploadImage 上传图片。
func (s *AppService) UploadImage(ctx context.Context, in mediabiz.UploadInput) (mediabiz.ImageInfo, error) {
	return mediabiz.UploadImage(ctx, s.cfg, in)
}
