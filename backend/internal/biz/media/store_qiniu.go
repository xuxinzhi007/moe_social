package mediabiz

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"strings"
	"sync"
	"time"

	"github.com/qiniu/go-sdk/v7/auth/qbox"
	"github.com/qiniu/go-sdk/v7/storage"
)

const (
	envQiniuAccessKey = "MOE_QINIU_ACCESS_KEY"
	envQiniuSecretKey = "MOE_QINIU_SECRET_KEY"
	// qiniuDownloadTTL 是服务端去七牛拉私有对象时签名的有效期。
	qiniuDownloadTTL = time.Hour
	// qiniuNotFoundCode 是七牛「对象不存在」。
	qiniuNotFoundCode = 612
	qiniuListPageSize = 1000
	qiniuHTTPTimeout  = 30 * time.Second
	// qiniuFileExistsCode 是七牛「文件已存在」。目录占位重复创建时忽略。
	qiniuFileExistsCode = 614
	qiniuPutTryTimes    = 3
)

// qiniuBlobStore 把用户媒体写到七牛 Kodo，下载走 CDN 域名。
type qiniuBlobStore struct {
	mac         *qbox.Mac
	bucket      string
	prefix      string
	cdnDomain   string
	private     bool
	proxyViaAPI bool
	uploader    *storage.FormUploader
	manager     *storage.BucketManager
	httpClient  *http.Client
	dirs        sync.Map
}

func newQiniuBlobStore(cfg ImageConfig) (*qiniuBlobStore, error) {
	qn := cfg.Qiniu
	accessKey := strings.TrimSpace(qn.AccessKey)
	secretKey := strings.TrimSpace(qn.SecretKey)
	if accessKey == "" {
		accessKey = strings.TrimSpace(os.Getenv(envQiniuAccessKey))
	}
	if secretKey == "" {
		secretKey = strings.TrimSpace(os.Getenv(envQiniuSecretKey))
	}
	bucket := strings.TrimSpace(qn.Bucket)
	domain := normalizeQiniuDomain(qn.CDNDomain)
	if accessKey == "" || secretKey == "" || bucket == "" || domain == "" {
		return nil, fmt.Errorf("qiniu config incomplete: need access_key, secret_key, bucket, cdn_domain (or %s / %s)", envQiniuAccessKey, envQiniuSecretKey)
	}
	zone, err := qiniuZone(qn.Region)
	if err != nil {
		return nil, err
	}
	mac := qbox.NewMac(accessKey, secretKey)
	st := &storage.Config{Zone: zone, UseHTTPS: true}
	// 私有空间的签名地址会过期，不能 302 给带一年缓存的取图接口。
	proxy := qn.ProxyViaAPI || qn.Private
	return &qiniuBlobStore{
		mac:         mac,
		bucket:      bucket,
		prefix:      strings.Trim(strings.TrimSpace(qn.Prefix), "/"),
		cdnDomain:   domain,
		private:     qn.Private,
		proxyViaAPI: proxy,
		uploader:    storage.NewFormUploader(st),
		manager:     storage.NewBucketManager(mac, st),
		httpClient:  &http.Client{Timeout: qiniuHTTPTimeout},
	}, nil
}

func (s *qiniuBlobStore) Put(ctx context.Context, folder, filename string, r io.Reader, contentType string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	key := objectKey(s.prefix, folder, filename)
	data, err := io.ReadAll(r)
	if err != nil {
		return fmt.Errorf("qiniu read upload: %w", err)
	}
	s.ensureDirs(ctx, key)
	if err := s.putBytes(ctx, key, data, contentType); err != nil {
		log.Printf("[media] qiniu put failed key=%s err=%v", key, err)
		return fmt.Errorf("qiniu put %s: %w", key, err)
	}
	return nil
}

func (s *qiniuBlobStore) putBytes(ctx context.Context, key string, data []byte, contentType string) error {
	policy := storage.PutPolicy{Scope: s.bucket + ":" + key}
	token := policy.UploadToken(s.mac)
	extra := &storage.PutExtra{TryTimes: qiniuPutTryTimes}
	if ct := strings.TrimSpace(contentType); ct != "" {
		extra.MimeType = ct
	}
	return s.uploader.Put(ctx, &storage.PutRet{}, token, key, bytes.NewReader(data), int64(len(data)), extra)
}

// ensureDirs 按对象键补七牛的空目录占位。没有这些以 / 结尾的对象时，控制台会把整段路径显示成根目录下的文件名。
func (s *qiniuBlobStore) ensureDirs(ctx context.Context, objectKey string) {
	for _, marker := range qiniuDirMarkers(objectKey) {
		if _, ok := s.dirs.Load(marker); ok {
			continue
		}
		err := s.putBytes(ctx, marker, nil, "")
		if err != nil && !qiniuIsCode(err, qiniuFileExistsCode) {
			log.Printf("[media] qiniu mkdir %s: %v", marker, err)
			continue
		}
		s.dirs.Store(marker, struct{}{})
	}
}

// qiniuDirMarkers 返回对象键的每一级目录，例如 media/1_xxz/post/a.png → media/、media/1_xxz/、media/1_xxz/post/。
func qiniuDirMarkers(objectKey string) []string {
	objectKey = strings.Trim(strings.ReplaceAll(strings.TrimSpace(objectKey), "\\", "/"), "/")
	dir, file := path.Split(objectKey)
	if file == "" {
		return nil
	}
	dir = strings.Trim(dir, "/")
	if dir == "" {
		return nil
	}
	parts := strings.Split(dir, "/")
	out := make([]string, 0, len(parts))
	acc := ""
	for _, part := range parts {
		if part == "" {
			continue
		}
		if acc == "" {
			acc = part
		} else {
			acc += "/" + part
		}
		out = append(out, acc+"/")
	}
	return out
}

func (s *qiniuBlobStore) Delete(_ context.Context, folder, filename string) error {
	key := objectKey(s.prefix, folder, filename)
	err := s.manager.Delete(s.bucket, key)
	if err == nil || qiniuIsNotFound(err) {
		return nil
	}
	return fmt.Errorf("qiniu delete %s: %w", key, err)
}

func (s *qiniuBlobStore) Open(ctx context.Context, folder, filename string) (BlobObject, error) {
	key := objectKey(s.prefix, folder, filename)
	info, err := s.manager.Stat(s.bucket, key)
	if err != nil {
		if qiniuIsNotFound(err) {
			return BlobObject{}, os.ErrNotExist
		}
		return BlobObject{}, fmt.Errorf("qiniu stat %s: %w", key, err)
	}
	obj := BlobObject{
		Size:        info.Fsize,
		ModTime:     qiniuPutTime(info.PutTime),
		ContentType: info.MimeType,
	}
	if obj.ContentType == "" {
		obj.ContentType = contentTypeForName(filename)
	}
	download := s.downloadURL(key)
	if !s.proxyViaAPI {
		obj.PublicURL = download
		return obj, nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, download, nil)
	if err != nil {
		return BlobObject{}, fmt.Errorf("qiniu download request: %w", err)
	}
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return BlobObject{}, fmt.Errorf("qiniu download %s: %w", key, err)
	}
	if resp.StatusCode == http.StatusNotFound {
		_ = resp.Body.Close()
		return BlobObject{}, os.ErrNotExist
	}
	if resp.StatusCode != http.StatusOK {
		_ = resp.Body.Close()
		return BlobObject{}, fmt.Errorf("qiniu download %s: status %d", key, resp.StatusCode)
	}
	if obj.Size == 0 && resp.ContentLength > 0 {
		obj.Size = resp.ContentLength
	}
	obj.Body = resp.Body
	return obj, nil
}

func (s *qiniuBlobStore) ListFolder(ctx context.Context, folder string) ([]BlobMeta, error) {
	prefix := objectKey(s.prefix, folder, "")
	if !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}
	return s.listPrefix(ctx, prefix, pathBaseFolder(folder))
}

func (s *qiniuBlobStore) ListAll(ctx context.Context) ([]BlobMeta, error) {
	prefix := ""
	if s.prefix != "" {
		prefix = s.prefix + "/"
	}
	return s.listPrefix(ctx, prefix, "")
}

func (s *qiniuBlobStore) listPrefix(ctx context.Context, prefix, forceFolder string) ([]BlobMeta, error) {
	var out []BlobMeta
	marker := ""
	for {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		entries, _, next, hasNext, err := s.manager.ListFiles(s.bucket, prefix, "", marker, qiniuListPageSize)
		if err != nil {
			return nil, fmt.Errorf("qiniu list: %w", err)
		}
		for _, item := range entries {
			rel := item.Key
			if s.prefix != "" {
				rel = strings.TrimPrefix(rel, s.prefix+"/")
			}
			folder, filename, ok := metaFromRel(rel)
			if !ok {
				continue
			}
			if forceFolder != "" && folder != forceFolder {
				continue
			}
			out = append(out, BlobMeta{
				Folder:    folder,
				Filename:  filename,
				Size:      item.Fsize,
				ModTime:   qiniuPutTime(item.PutTime),
				ObjectKey: item.Key,
			})
		}
		if !hasNext || next == "" {
			break
		}
		marker = next
	}
	return out, nil
}

func (s *qiniuBlobStore) downloadURL(key string) string {
	if !s.private {
		return storage.MakePublicURL(s.cdnDomain, key)
	}
	deadline := time.Now().Add(qiniuDownloadTTL).Unix()
	return storage.MakePrivateURL(s.mac, s.cdnDomain, key, deadline)
}

func pathBaseFolder(folder string) string {
	return cleanFolder(folder)
}

func qiniuZone(region string) (*storage.Zone, error) {
	switch strings.ToLower(strings.TrimSpace(region)) {
	case "", "z2", "huanan", "cn-south-1":
		return &storage.ZoneHuanan, nil
	case "z0", "huadong", "cn-east-1":
		return &storage.ZoneHuadong, nil
	case "z1", "huabei", "cn-north-1":
		return &storage.ZoneHuabei, nil
	case "na0", "beimei":
		return &storage.ZoneBeimei, nil
	case "as0", "xinjiapo":
		return &storage.ZoneXinjiapo, nil
	default:
		return nil, fmt.Errorf("qiniu region %q: use z0, z1, or z2", region)
	}
}

func normalizeQiniuDomain(raw string) string {
	domain := strings.TrimRight(strings.TrimSpace(raw), "/")
	if domain == "" {
		return ""
	}
	if !strings.Contains(domain, "://") {
		domain = "http://" + domain
	}
	return domain
}

func qiniuPutTime(ticks int64) time.Time {
	if ticks <= 0 {
		return time.Time{}
	}
	// 七牛 PutTime 单位是 100 纳秒。
	return time.Unix(0, ticks*100).UTC()
}

func qiniuIsNotFound(err error) bool {
	return qiniuIsCode(err, qiniuNotFoundCode)
}

func qiniuIsCode(err error, code int) bool {
	var info *storage.ErrorInfo
	return errors.As(err, &info) && info != nil && info.Code == code
}
