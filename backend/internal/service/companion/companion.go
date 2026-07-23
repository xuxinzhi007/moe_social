package companionapp

import (
	"context"

	companionbiz "backend/internal/biz/companion"
)

// AppService Companion 应用服务层。
type AppService struct {
	engine *companionbiz.Engine
	hub    *companionbiz.CompanionWSHub
}

// New creates a Companion application service from injected business dependencies.
func New(engine *companionbiz.Engine, hub *companionbiz.CompanionWSHub) *AppService {
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
	}

	return &AppService{engine: engine, hub: hub}
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
