// Package aiapp AI 资源域应用服务。
package aiapp

import (
	aibiz "backend/internal/biz/ai"
)

// AppService AI 资源应用层。
type AppService struct {
	resources *aibiz.ResourcesUsecase
}

// New 构造 AppService。
func New(resources *aibiz.ResourcesUsecase) *AppService {
	return &AppService{resources: resources}
}
