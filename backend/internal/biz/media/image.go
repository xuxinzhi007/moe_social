package mediabiz

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// ImageConfig 本地图片存储配置。
type ImageConfig struct {
	LocalDir       string
	PublicBaseURL  string
}

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

// ImageFile 可读图片文件。
type ImageFile struct {
	Path         string
	Filename     string
	ModTime      time.Time
	ContentType  string
}

func normalizeImageDir(cfg ImageConfig) string {
	dir := strings.TrimSpace(cfg.LocalDir)
	if dir == "" {
		return "./data/images"
	}
	return dir
}

func normalizeBaseURL(cfg ImageConfig) string {
	base := strings.TrimRight(strings.TrimSpace(cfg.PublicBaseURL), "/")
	if base == "" {
		return "http://localhost:8888"
	}
	return base
}

// ListImages 列出用户目录下的图片。
func ListImages(_ context.Context, cfg ImageConfig, in ListImagesInput) (ListImagesResult, error) {
	imgDir := normalizeImageDir(cfg)
	userDir := filepath.Join(imgDir, in.UserFolder)

	files, err := os.ReadDir(userDir)
	if err != nil {
		if os.IsNotExist(err) {
			return ListImagesResult{Items: []ImageInfo{}, Total: 0}, nil
		}
		return ListImagesResult{}, err
	}

	base := normalizeBaseURL(cfg)
	imageInfos := make([]ImageInfo, 0, len(files))
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		info, err := file.Info()
		if err != nil {
			continue
		}
		filename := file.Name()
		key := fmt.Sprintf("%s__%s", in.UserFolder, filename)
		imageInfos = append(imageInfos, ImageInfo{
			ID:        key,
			Filename:  key,
			URL:       fmt.Sprintf("%s/api/images/%s", base, key),
			Size:      info.Size(),
			CreatedAt: info.ModTime().Format("2006-01-02 15:04:05"),
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
func DeleteImage(_ context.Context, cfg ImageConfig, userFolder, key string) error {
	folder, filename, ok := SplitImageKey(key)
	if !ok || folder != userFolder {
		return os.ErrPermission
	}
	folder = filepath.Base(folder)
	filename = filepath.Base(filename)
	imgPath := filepath.Join(normalizeImageDir(cfg), folder, filename)

	if _, err := os.Stat(imgPath); os.IsNotExist(err) {
		return nil
	}
	return os.Remove(imgPath)
}

// OpenImage 打开图片供 HTTP 输出。
func OpenImage(_ context.Context, cfg ImageConfig, key string) (ImageFile, error) {
	folder, filename, ok := SplitImageKey(key)
	if !ok {
		return ImageFile{}, os.ErrNotExist
	}
	folder = filepath.Base(folder)
	filename = filepath.Base(filename)
	imgPath := filepath.Join(normalizeImageDir(cfg), folder, filename)

	info, err := os.Stat(imgPath)
	if err != nil {
		return ImageFile{}, err
	}

	contentType := "image/jpeg"
	switch filepath.Ext(filename) {
	case ".png":
		contentType = "image/png"
	case ".gif":
		contentType = "image/gif"
	case ".webp":
		contentType = "image/webp"
	case ".svg":
		contentType = "image/svg+xml"
	}

	return ImageFile{
		Path:        imgPath,
		Filename:    filename,
		ModTime:     info.ModTime(),
		ContentType: contentType,
	}, nil
}

// UploadImage 保存上传文件。
func UploadImage(_ context.Context, cfg ImageConfig, in UploadInput) (ImageInfo, error) {
	imgDir := normalizeImageDir(cfg)
	userDir := filepath.Join(imgDir, in.UserFolder)
	if err := os.MkdirAll(userDir, os.ModePerm); err != nil {
		return ImageInfo{}, err
	}

	timestamp := time.Now().Unix()
	orig := filepath.Base(in.OrigName)
	filename := fmt.Sprintf("%d_%s", timestamp, orig)
	imgPath := filepath.Join(userDir, filename)

	outFile, err := os.Create(imgPath)
	if err != nil {
		return ImageInfo{}, err
	}
	defer outFile.Close()

	if _, err := io.Copy(outFile, in.Reader); err != nil {
		return ImageInfo{}, err
	}

	info, err := outFile.Stat()
	if err != nil {
		return ImageInfo{}, err
	}

	key := fmt.Sprintf("%s__%s", in.UserFolder, filename)
	return ImageInfo{
		ID:        key,
		Filename:  key,
		URL:       fmt.Sprintf("/api/images/%s", key),
		Size:      info.Size(),
		CreatedAt: time.Now().Format("2006-01-02 15:04:05"),
	}, nil
}
