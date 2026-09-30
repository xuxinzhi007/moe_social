package mediabiz

import (
	"context"
	"io"
	"path"
	"strings"
	"time"
)

// DriverLocal / DriverOSS / DriverQiniu 为 image.driver 合法值。
const (
	DriverLocal = "local"
	DriverOSS   = "oss"
	DriverQiniu = "qiniu"
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

// QiniuConfig 七牛对象存储。密钥可用环境变量 MOE_QINIU_ACCESS_KEY / MOE_QINIU_SECRET_KEY。
type QiniuConfig struct {
	AccessKey string
	SecretKey string
	Bucket    string
	// CDNDomain 下载域名，无尾斜杠。测试域名如 http://xxx.hn-bkt.clouddn.com。
	CDNDomain string
	// Region 存储区域：z0 华东、z1 华北、z2 华南。空则按华南。
	Region string
	// Prefix 对象前缀，如 media。
	Prefix string
	// Private 为 true 时下载地址带签名。私有空间必须为 true。
	Private bool
	// ProxyViaAPI 为 true 时由 API 拉流，不把下载地址 302 给客户端。
	// 私有空间强制走反代：签名地址会过期，而取图响应带了一年缓存。
	ProxyViaAPI bool
}

// ImageConfig 图片/语音对象存储配置。
type ImageConfig struct {
	Driver        string // local | oss | qiniu；空等同 local
	LocalDir      string
	PublicBaseURL string
	OSS           OSSConfig
	Qiniu         QiniuConfig
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
	case DriverQiniu:
		return DriverQiniu
	default:
		return DriverLocal
	}
}

func objectKey(prefix, folder, filename string) string {
	p := strings.Trim(strings.TrimSpace(prefix), "/")
	folder = cleanFolder(folder)
	filename = strings.TrimSpace(filename)
	if filename != "" {
		filename = path.Base(filename)
	}
	if filename == "" || filename == "." {
		if folder == "" {
			if p == "" {
				return ""
			}
			return p + "/"
		}
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

// cleanFolder 保留「用户目录/分类」这种多段路径，并拒绝 .. 。
func cleanFolder(folder string) string {
	folder = strings.Trim(strings.ReplaceAll(strings.TrimSpace(folder), "\\", "/"), "/")
	if folder == "" {
		return ""
	}
	parts := strings.Split(folder, "/")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" || part == "." || part == ".." || strings.ContainsAny(part, `/\`) {
			return ""
		}
		out = append(out, part)
	}
	return strings.Join(out, "/")
}

// metaFromRel 解析对象相对路径。两段是旧数据，三段是「用户/分类/文件」。
func metaFromRel(rel string) (folder, filename string, ok bool) {
	rel = strings.Trim(strings.TrimSpace(rel), "/")
	parts := strings.Split(rel, "/")
	switch len(parts) {
	case 2:
		folder, filename = parts[0], parts[1]
	case 3:
		folder, filename = parts[0]+"/"+parts[1], parts[2]
	default:
		return "", "", false
	}
	if cleanFolder(folder) != folder || filename == "" || filename == "." || strings.Contains(filename, "/") {
		return "", "", false
	}
	return folder, filename, true
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
	folder = strings.ReplaceAll(cleanFolder(folder), "/", "__")
	return folder + "__" + filename
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
	case DriverQiniu:
		qiniuStore, err := newQiniuBlobStore(cfg)
		if err != nil {
			return nil, err
		}
		local := newLocalBlobStore(cfg)
		return &hybridBlobStore{primary: qiniuStore, fallback: local}, nil
	default:
		return newLocalBlobStore(cfg), nil
	}
}
