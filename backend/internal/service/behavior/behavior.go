// Package behaviorapp 用户行为埋点应用服务（Sprint S4）。
package behaviorapp

import (
	"gorm.io/gorm"
	behaviorbiz "backend/internal/biz/behavior"
	behaviordata "backend/internal/data/behavior"
)

// Package behaviorapp 用户行为埋点应用服务（Sprint S4）。

// AppService 行为域应用层。
type AppService struct {
	store behaviorbiz.BehaviorStore
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{store: behaviordata.NewStore(db)}
}
