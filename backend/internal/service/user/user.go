// Package userapp User 域应用服务基础定义。
package userapp

import (
	notifybiz "backend/internal/biz/notify"
	userbiz "backend/internal/biz/user"
	notifydata "backend/internal/data/notify"
	userdata "backend/internal/data/user"
	"backend/internal/oauthflow"
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
	// oauthTx 是第三方登录的授权事务存储。生产路径用进程内共享的 oauthflow.Default() ——
	// 发起授权、供应商回调、随后的 login 是三次独立请求，只有同一份存储才能串起来。
	oauthTx *oauthflow.Store
}

type CompanionEventRecorder func(context.Context, uint, string, uint, map[string]interface{}) error

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{
		db:      db,
		store:   userdata.NewUserStore(db),
		notify:  notifydata.NewStore(db),
		oauthTx: oauthflow.Default(),
	}
}

// SetOAuthStoreForTest 替换授权事务存储，返回自身以便链式构造。
//
// 仅供测试：用来注入假时钟（测过期而不真等 10 分钟）、定长随机源和固定回跳白名单。
// 生产路径不要调用 —— 换掉共享存储会让回调与 login 查不到彼此的事务。
func (s *AppService) SetOAuthStoreForTest(txs *oauthflow.Store) *AppService {
	if txs != nil {
		s.oauthTx = txs
	}
	return s
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
