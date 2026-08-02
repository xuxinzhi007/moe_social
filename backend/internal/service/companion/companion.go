package companionapp

import (
	"context"

	companionbiz "backend/internal/biz/companion"
	"backend/model"
	"gorm.io/gorm"
)

// AppService Companion 应用服务层。
type AppService struct {
	engine *companionbiz.Engine
	hub    *companionbiz.CompanionWSHub
	db     *gorm.DB
}

// New creates a Companion application service from injected business dependencies.
func New(engine *companionbiz.Engine, hub *companionbiz.CompanionWSHub, db *gorm.DB) *AppService {
	if engine == nil {
		return &AppService{}
	}
	if hub != nil {
		hub.SetEngine(engine)
	}

	if hub != nil {
		engine.OnGreeting = func(userID uint, greeting string) {
			state, _, err := engine.GetState(context.Background(), userID)
			if err == nil && state != nil {
				hub.BroadcastGreeting(userID, greeting, state.MoodThought, state.ActivityLabel)
			}
		}
		engine.OnProactive = func(userID uint, message, reason string) (uint, bool) {
			if db != nil {
				notice := &model.Notification{
					UserID:  userID,
					Type:    9,
					Content: message,
				}
				if err := db.WithContext(context.Background()).Create(notice).Error; err != nil {
					// WS delivery still proceeds when the inbox write is unavailable.
				} else {
					hub.BroadcastProactive(userID, message, reason, notice.ID)
					return notice.ID, true
				}
			}
			hub.BroadcastProactive(userID, message, reason, 0)
			return 0, true
		}
		engine.OnEvent = hub.BroadcastCompanionEvent
	}

	return &AppService{engine: engine, hub: hub, db: db}
}

// Hub 暴露 WebSocket Hub（供 transport 层注册路由）。
func (s *AppService) Hub() *companionbiz.CompanionWSHub {
	if s == nil {
		return nil
	}
	return s.hub
}

// Start 启动后台任务（记忆清理 + 问候广播）。
func (s *AppService) Start(ctx context.Context) {
	if s == nil || s.engine == nil {
		return
	}
	s.engine.StartCleanup(ctx)
	s.engine.StartGreetingTicker(ctx)
}

// Stop 停止后台任务。
func (s *AppService) Stop() {
	if s == nil || s.engine == nil {
		return
	}
	s.engine.StopCleanup()
	s.engine.StopGreetingTicker()
}
