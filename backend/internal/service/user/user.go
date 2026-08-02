// Package userapp User 域应用服务基础定义。
package userapp

import (
	notifybiz "backend/internal/biz/notify"
	userbiz "backend/internal/biz/user"
	notifydata "backend/internal/data/notify"
	userdata "backend/internal/data/user"
	"backend/model"
	"context"
	"gorm.io/gorm"
	"strconv"
)

// Package userapp User 域应用服务基础定义。

// AppService User 应用服务。
type AppService struct {
	db                     *gorm.DB
	store                  userbiz.UserStore
	notify                 notifybiz.NotifyStore
	companionEventRecorder CompanionEventRecorder
}

type CompanionEventRecorder func(context.Context, uint, string, uint, map[string]interface{}) error

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		db:     db,
		store:  userdata.NewUserStore(db),
		notify: notifydata.NewStore(db),
	}
}

// DB 暴露给渐进迁移（仅 Hybrid 内部）。
func (s *AppService) DB() *gorm.DB {
	return s.db
}

// Store 暴露 UserStore（Hybrid 内部）。
func (s *AppService) Store() userbiz.UserStore {
	return s.store
}

// Notify 暴露 NotifyStore（Hybrid GW 内部）。
func (s *AppService) Notify() notifybiz.NotifyStore {
	return s.notify
}

// EnsureUser 加载用户（供扩展）。
func (s *AppService) EnsureUser(ctx context.Context, userID uint) (model.User, error) {
	return userbiz.GetByID(ctx, s.store, userID)
}

func (s *AppService) SetCompanionEventRecorder(recorder CompanionEventRecorder) {
	if s == nil {
		return
	}
	s.companionEventRecorder = recorder
}

func (s *AppService) recordCompanionEvent(
	ctx context.Context,
	userID uint,
	eventType, requestID string,
	payload map[string]interface{},
) {
	if s == nil || s.companionEventRecorder == nil || userID == 0 {
		return
	}
	requestIDValue, _ := strconv.ParseUint(requestID, 10, 32)
	_ = s.companionEventRecorder(ctx, userID, eventType, uint(requestIDValue), payload)
}
