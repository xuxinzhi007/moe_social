package mediabiz

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

type ossBlobStore struct {
	bucket        *oss.Bucket
	prefix        string
	publicBase    string
	proxyViaAPI   bool
}

func newOSSBlobStore(cfg ImageConfig) (*ossBlobStore, error) {
	endpoint := strings.TrimSpace(cfg.OSS.Endpoint)
	bucketName := strings.TrimSpace(cfg.OSS.Bucket)
	ak := strings.TrimSpace(cfg.OSS.AccessKeyID)
	sk := strings.TrimSpace(cfg.OSS.AccessKeySecret)
	if ak == "" {
		ak = strings.TrimSpace(os.Getenv("MOE_OSS_ACCESS_KEY_ID"))
	}
	if sk == "" {
		sk = strings.TrimSpace(os.Getenv("MOE_OSS_ACCESS_KEY_SECRET"))
	}
	if endpoint == "" || bucketName == "" || ak == "" || sk == "" {
		return nil, fmt.Errorf("oss config incomplete: need endpoint, bucket, access_key_id, access_key_secret (or MOE_OSS_* env)")
	}

	endpoint = strings.TrimPrefix(endpoint, "https://")
	endpoint = strings.TrimPrefix(endpoint, "http://")

	client, err := oss.New(endpoint, ak, sk)
	if err != nil {
		return nil, fmt.Errorf("oss client: %w", err)
	}
	bucket, err := client.Bucket(bucketName)
	if err != nil {
		return nil, fmt.Errorf("oss bucket: %w", err)
	}

	publicBase := strings.TrimRight(strings.TrimSpace(cfg.OSS.PublicBaseURL), "/")
	if publicBase == "" {
		publicBase = fmt.Sprintf("https://%s.%s", bucketName, endpoint)
	}

	return &ossBlobStore{
		bucket:      bucket,
		prefix:      strings.Trim(strings.TrimSpace(cfg.OSS.Prefix), "/"),
		publicBase:  publicBase,
		proxyViaAPI: cfg.OSS.ProxyViaAPI,
	}, nil
}

func (s *ossBlobStore) key(folder, filename string) string {
	return objectKey(s.prefix, folder, filename)
}

func (s *ossBlobStore) publicURL(objectKey string) string {
	return s.publicBase + "/" + strings.TrimLeft(objectKey, "/")
}

func (s *ossBlobStore) Put(_ context.Context, folder, filename string, r io.Reader, contentType string) error {
	opts := []oss.Option{}
	if strings.TrimSpace(contentType) != "" {
		opts = append(opts, oss.ContentType(contentType))
	}
	if err := s.bucket.PutObject(s.key(folder, filename), r, opts...); err != nil {
		return fmt.Errorf("oss put: %w", err)
	}
	return nil
}

func (s *ossBlobStore) Delete(_ context.Context, folder, filename string) error {
	if err := s.bucket.DeleteObject(s.key(folder, filename)); err != nil {
		return fmt.Errorf("oss delete: %w", err)
	}
	return nil
}

func (s *ossBlobStore) Open(_ context.Context, folder, filename string) (BlobObject, error) {
	objectKey := s.key(folder, filename)
	header, err := s.bucket.GetObjectMeta(objectKey)
	if err != nil {
		return BlobObject{}, err
	}
	body, err := s.bucket.GetObject(objectKey)
	if err != nil {
		return BlobObject{}, err
	}

	size := int64(0)
	if v := header.Get(http.CanonicalHeaderKey("Content-Length")); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			size = n
		}
	}
	mod := time.Now()
	if lm := header.Get("Last-Modified"); lm != "" {
		if t, err := http.ParseTime(lm); err == nil {
			mod = t
		}
	}
	ct := header.Get("Content-Type")
	if ct == "" {
		ct = contentTypeForName(filename)
	}

	obj := BlobObject{
		Body:        body,
		Size:        size,
		ModTime:     mod,
		ContentType: ct,
	}
	if !s.proxyViaAPI {
		obj.PublicURL = s.publicURL(objectKey)
	}
	return obj, nil
}

func (s *ossBlobStore) ListFolder(_ context.Context, folder string) ([]BlobMeta, error) {
	prefix := s.key(folder, "")
	if !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}
	return s.listPrefix(prefix, filepathBaseFolder(folder))
}

func (s *ossBlobStore) ListAll(_ context.Context) ([]BlobMeta, error) {
	prefix := ""
	if s.prefix != "" {
		prefix = s.prefix + "/"
	}
	return s.listPrefix(prefix, "")
}

func filepathBaseFolder(folder string) string {
	return path.Base(strings.TrimSpace(folder))
}

func (s *ossBlobStore) listPrefix(prefix, forceFolder string) ([]BlobMeta, error) {
	var out []BlobMeta
	marker := ""
	for {
		res, err := s.bucket.ListObjects(oss.Prefix(prefix), oss.Marker(marker), oss.MaxKeys(500))
		if err != nil {
			return nil, fmt.Errorf("oss list: %w", err)
		}
		for _, obj := range res.Objects {
			rel := obj.Key
			if s.prefix != "" {
				rel = strings.TrimPrefix(rel, s.prefix+"/")
			}
			parts := strings.Split(rel, "/")
			if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
				continue
			}
			folder := parts[0]
			if forceFolder != "" && folder != forceFolder {
				continue
			}
			out = append(out, BlobMeta{
				Folder:    folder,
				Filename:  parts[1],
				Size:      obj.Size,
				ModTime:   obj.LastModified,
				ObjectKey: obj.Key,
			})
		}
		if !res.IsTruncated {
			break
		}
		marker = res.NextMarker
	}
	return out, nil
}
