package companionapp

import (
	"context"

	"gorm.io/gorm"

	lifebiz "backend/internal/biz/life"
	companionbiz "backend/internal/biz/companion"
	companiondata "backend/internal/data/companion"
	"backend/pkg/llminference"
)

// Deps Companion 服务依赖。
type Deps struct {
	Inference llminference.Config
	Model     string
}

// AppService Companion 应用服务层。
type AppService struct {
	engine *companionbiz.Engine
	hub    *companionbiz.CompanionWSHub
}

// New 创建 Companion AppService。lifeStore 可为 nil。
func New(db *gorm.DB, deps Deps, lifeStore lifebiz.Store) *AppService {
	store := companiondata.NewStore(db)
	if store == nil {
		return &AppService{}
	}
	engine := companionbiz.NewEngine(store, lifeStore, deps.Inference, deps.Model)
	hub := companionbiz.NewCompanionWSHub()
	hub.SetEngine(engine)

	// 连接 Engine 问候回调 → Hub 广播
	engine.OnGreeting = func(userID uint, greeting string) {
		state, _, err := engine.GetState(context.Background(), userID)
		if err == nil && state != nil {
			hub.BroadcastGreeting(greeting, state.MoodThought, state.ActivityLabel)
		}
	}

	return &AppService{engine: engine, hub: hub}
}

// Engine 暴露引擎（供 SSE 流式端点使用）。
func (s *AppService) Engine() *companionbiz.Engine {
	if s == nil {
		return nil
	}
	return s.engine
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
