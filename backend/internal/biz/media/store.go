package mediabiz

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"
	"time"
)

// DriverLocal / DriverOSS 为 image.driver 合法值。
const (
	DriverLocal = "local"
	DriverOSS   = "oss"
)

// OSSConfig 阿里云 OSS（密钥可用环境变量 MOE_OSS_ACCESS_KEY_ID / MOE_OSS_ACCESS_KEY_SECRET）。
type OSSConfig struct {
	Endpoint        string
	Bucket          string
	AccessKeyID     string
	AccessKeySecret string
	// Prefix 对象前缀，如 media。
	Prefix string
	// PublicBaseURL 公网或 CDN 基址（无尾斜杠）。空则用 https://{bucket}.{endpoint}。
	PublicBaseURL string
	Region        string
	// ProxyViaAPI 为 true 时不 302，由 API 反代读对象（适合桶未公开读）。
	ProxyViaAPI bool
}

// ImageConfig 图片/语音对象存储配置。
type ImageConfig struct {
	Driver        string // local | oss；空等同 local
	LocalDir      string
	PublicBaseURL string
	OSS           OSSConfig
}

// BlobMeta 对象元数据（列表用）。
type BlobMeta struct {
	Folder    string
	Filename  string
	Size      int64
	ModTime   time.Time
	ObjectKey string
}

// BlobObject 可读对象。
type BlobObject struct {
	Body        io.ReadCloser
	Size        int64
	ModTime     time.Time
	ContentType string
	// LocalPath 仅 local；供 http.ServeContent 使用。
	LocalPath string
	// PublicURL 若非空，HTTP 可 302 到 OSS/CDN。
	PublicURL string
}

// BlobStore 用户媒体对象存储。
type BlobStore interface {
	Put(ctx context.Context, folder, filename string, r io.Reader, contentType string) error
	Delete(ctx context.Context, folder, filename string) error
	Open(ctx context.Context, folder, filename string) (BlobObject, error)
	ListFolder(ctx context.Context, folder string) ([]BlobMeta, error)
	ListAll(ctx context.Context) ([]BlobMeta, error)
}

func normalizeDriver(d string) string {
	switch strings.ToLower(strings.TrimSpace(d)) {
	case DriverOSS:
		return DriverOSS
	default:
		return DriverLocal
	}
}

func objectKey(prefix, folder, filename string) string {
	p := strings.Trim(strings.TrimSpace(prefix), "/")
	folder = path.Base(strings.TrimSpace(folder))
	filename = strings.TrimSpace(filename)
	if filename != "" {
		filename = path.Base(filename)
	}
	if filename == "" || filename == "." {
		if p == "" {
			return folder + "/"
		}
		return path.Join(p, folder) + "/"
	}
	if p == "" {
		return path.Join(folder, filename)
	}
	return path.Join(p, folder, filename)
}

func contentTypeForName(filename string) string {
	switch strings.ToLower(path.Ext(filename)) {
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	case ".svg":
		return "image/svg+xml"
	case ".m4a":
		return "audio/mp4"
	case ".mp3":
		return "audio/mpeg"
	case ".aac":
		return "audio/aac"
	case ".wav":
		return "audio/wav"
	case ".ogg":
		return "audio/ogg"
	default:
		return "image/jpeg"
	}
}

func imageKey(folder, filename string) string {
	return fmt.Sprintf("%s__%s", folder, filename)
}

// NewBlobStore 按 driver 构造存储；oss 配置不全时返回错误。
func NewBlobStore(cfg ImageConfig) (BlobStore, error) {
	switch normalizeDriver(cfg.Driver) {
	case DriverOSS:
		ossStore, err := newOSSBlobStore(cfg)
		if err != nil {
			return nil, err
		}
		local := newLocalBlobStore(cfg)
		return &hybridBlobStore{primary: ossStore, fallback: local}, nil
	default:
		return newLocalBlobStore(cfg), nil
	}
}
