// Package mediaapp 本地图片媒体应用服务。
package mediaapp

import (
	mediabiz "backend/internal/biz/media"
)

// Package mediaapp 本地图片媒体应用服务。

// AppService 图片媒体应用层。
type AppService struct {
	cfg mediabiz.ImageConfig
}

// New 构造 AppService。
func New(cfg mediabiz.ImageConfig) *AppService {
	return &AppService{cfg: cfg}
}
