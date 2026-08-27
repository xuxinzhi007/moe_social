package mediabiz

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// ImageInfo 图片元数据。
type ImageInfo struct {
	ID        string
	Filename  string
	URL       string
	Size      int64
	CreatedAt string
}

// ListImagesInput 列表请求。
type ListImagesInput struct {
	UserFolder string
	Page       int
	PageSize   int
}

// ListImagesResult 分页列表结果。
type ListImagesResult struct {
	Items []ImageInfo
	Total int
}

// UploadInput 上传参数。
type UploadInput struct {
	UserFolder string
	OrigName   string
	Reader     io.Reader
}

// ImageFile 可读图片文件（兼容本地路径与流式 Body）。
type ImageFile struct {
	Path        string
	Body        io.ReadCloser
	Size        int64
	Filename    string
	ModTime     time.Time
	ContentType string
	PublicURL   string
}

// imageExtensions 图库允许的图片扩展名白名单。
var imageExtensions = map[string]struct{}{
	".jpg": {}, ".jpeg": {}, ".png": {}, ".gif": {},
	".webp": {}, ".svg": {}, ".heic": {}, ".bmp": {},
}

// audioExtensions 语音消息允许的音频扩展名白名单。
var audioExtensions = map[string]struct{}{
	".m4a": {}, ".mp3": {}, ".aac": {}, ".wav": {}, ".ogg": {},
}

func normalizeBaseURL(cfg ImageConfig) string {
	base := strings.TrimRight(strings.TrimSpace(cfg.PublicBaseURL), "/")
	if base == "" {
		return "http://localhost:8888"
	}
	return base
}

func mustStore(cfg ImageConfig) (BlobStore, error) {
	return NewBlobStore(cfg)
}

// ListImages 列出用户目录下的图片。
func ListImages(ctx context.Context, cfg ImageConfig, in ListImagesInput) (ListImagesResult, error) {
	store, err := mustStore(cfg)
	if err != nil {
		return ListImagesResult{}, err
	}
	return ListImagesWithStore(ctx, cfg, store, in)
}

// ListImagesWithStore 使用已构造的 store 列目录。
func ListImagesWithStore(ctx context.Context, cfg ImageConfig, store BlobStore, in ListImagesInput) (ListImagesResult, error) {
	metas, err := store.ListFolder(ctx, in.UserFolder)
	if err != nil {
		return ListImagesResult{}, err
	}

	base := normalizeBaseURL(cfg)
	imageInfos := make([]ImageInfo, 0, len(metas))
	for _, m := range metas {
		ext := strings.ToLower(filepath.Ext(m.Filename))
		if _, ok := imageExtensions[ext]; !ok {
			continue
		}
		key := imageKey(m.Folder, m.Filename)
		imageInfos = append(imageInfos, ImageInfo{
			ID:        key,
			Filename:  key,
			URL:       fmt.Sprintf("%s/api/images/%s", base, key),
			Size:      m.Size,
			CreatedAt: m.ModTime.Format("2006-01-02 15:04:05"),
		})
	}

	sort.Slice(imageInfos, func(i, j int) bool {
		return imageInfos[i].CreatedAt > imageInfos[j].CreatedAt
	})

	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}

	total := len(imageInfos)
	start := (page - 1) * pageSize
	end := start + pageSize
	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	var paginated []ImageInfo
	if start < total {
		paginated = imageInfos[start:end]
	} else {
		paginated = []ImageInfo{}
	}
	return ListImagesResult{Items: paginated, Total: total}, nil
}

// DeleteImage 删除用户图片。
func DeleteImage(ctx context.Context, cfg ImageConfig, userFolder, key string) error {
	store, err := mustStore(cfg)
	if err != nil {
		return err
	}
	return DeleteImageWithStore(ctx, store, userFolder, key)
}

// DeleteImageWithStore 使用已构造的 store 删除。
func DeleteImageWithStore(ctx context.Context, store BlobStore, userFolder, key string) error {
	folder, filename, ok := SplitImageKey(key)
	if !ok || folder != userFolder {
		return os.ErrPermission
	}
	return store.Delete(ctx, folder, filename)
}

// OpenImage 打开图片供 HTTP 输出。
func OpenImage(ctx context.Context, cfg ImageConfig, key string) (ImageFile, error) {
	store, err := mustStore(cfg)
	if err != nil {
		return ImageFile{}, err
	}
	return OpenImageWithStore(ctx, store, key)
}

// OpenImageWithStore 使用已构造的 store 打开。
func OpenImageWithStore(ctx context.Context, store BlobStore, key string) (ImageFile, error) {
	folder, filename, ok := SplitImageKey(key)
	if !ok {
		return ImageFile{}, os.ErrNotExist
	}
	obj, err := store.Open(ctx, folder, filename)
	if err != nil {
		return ImageFile{}, err
	}
	return ImageFile{
		Path:        obj.LocalPath,
		Body:        obj.Body,
		Size:        obj.Size,
		Filename:    filename,
		ModTime:     obj.ModTime,
		ContentType: obj.ContentType,
		PublicURL:   obj.PublicURL,
	}, nil
}

// UploadImage 保存上传文件。
func UploadImage(ctx context.Context, cfg ImageConfig, in UploadInput) (ImageInfo, error) {
	store, err := mustStore(cfg)
	if err != nil {
		return ImageInfo{}, err
	}
	return UploadImageWithStore(ctx, store, in)
}

// UploadImageWithStore 使用已构造的 store 上传。
func UploadImageWithStore(ctx context.Context, store BlobStore, in UploadInput) (ImageInfo, error) {
	ext := strings.ToLower(filepath.Ext(in.OrigName))
	if _, ok := imageExtensions[ext]; !ok {
		if _, ok := audioExtensions[ext]; !ok {
			return ImageInfo{}, fmt.Errorf("unsupported file extension: %s", ext)
		}
	}

	timestamp := time.Now().Unix()
	orig := filepath.Base(in.OrigName)
	filename := fmt.Sprintf("%d_%s", timestamp, orig)
	ct := contentTypeForName(filename)

	data, err := io.ReadAll(in.Reader)
	if err != nil {
		return ImageInfo{}, fmt.Errorf("read upload: %w", err)
	}
	if err := store.Put(ctx, in.UserFolder, filename, bytes.NewReader(data), ct); err != nil {
		return ImageInfo{}, err
	}

	key := imageKey(in.UserFolder, filename)
	return ImageInfo{
		ID:        key,
		Filename:  key,
		URL:       fmt.Sprintf("/api/images/%s", key),
		Size:      int64(len(data)),
		CreatedAt: time.Now().Format("2006-01-02 15:04:05"),
	}, nil
}

// SaveImageBytes 将内存中的图片写入用户目录（服务端生成缩略图等）。
func SaveImageBytes(ctx context.Context, cfg ImageConfig, userFolder, origName string, data []byte) (ImageInfo, error) {
	if len(data) == 0 {
		return ImageInfo{}, fmt.Errorf("empty image data")
	}
	return UploadImage(ctx, cfg, UploadInput{
		UserFolder: userFolder,
		OrigName:   origName,
		Reader:     bytes.NewReader(data),
	})
}
