package mediaapp

import (
	"fmt"

	mediabiz "backend/internal/biz/media"
)

// AppService 图片媒体应用层。
type AppService struct {
	cfg   mediabiz.ImageConfig
	store mediabiz.BlobStore
}

// New 构造 AppService。driver=oss 且配置不全时返回错误。
func New(cfg mediabiz.ImageConfig) (*AppService, error) {
	store, err := mediabiz.NewBlobStore(cfg)
	if err != nil {
		return nil, fmt.Errorf("media store: %w", err)
	}
	return &AppService{cfg: cfg, store: store}, nil
}

// Config 返回当前图片配置。
func (s *AppService) Config() mediabiz.ImageConfig {
	if s == nil {
		return mediabiz.ImageConfig{}
	}
	return s.cfg
}

// Store 返回底层 BlobStore。
func (s *AppService) Store() mediabiz.BlobStore {
	if s == nil {
		return nil
	}
	return s.store
}
