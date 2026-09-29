package companionapp

import (
	"context"

	companionbiz "backend/internal/biz/companion"
	"backend/model"
	"backend/pkg/llminference"
	"gorm.io/gorm"
)

// InferenceResolver 按用户已保存的供应商解析推理配置。
// 返回 nil 配置表示继续使用服务端默认模型。
type InferenceResolver func(ctx context.Context, userID uint) (*llminference.Config, error)

// AppService Companion 应用服务层。
type AppService struct {
	engine           *companionbiz.Engine
	hub              *companionbiz.CompanionWSHub
	db               *gorm.DB
	resolveInference InferenceResolver
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

// UseInferenceResolver 注入用户供应商解析。未注入时聊天使用服务端默认模型。
func (s *AppService) UseInferenceResolver(resolve InferenceResolver) {
	if s == nil {
		return
	}
	s.resolveInference = resolve
}

// ResolveChatInference 读取当前用户已保存的外部供应商。
func (s *AppService) ResolveChatInference(ctx context.Context, userID uint) (*llminference.Config, error) {
	if s == nil || s.resolveInference == nil {
		return nil, nil
	}
	return s.resolveInference(ctx, userID)
}

// Hub 暴露 WebSocket Hub（供 transport 层注册路由）。
func (s *AppService) Hub() *companionbiz.CompanionWSHub {
	if s == nil {
		return nil
	}
	return s.hub
}

// Start starts background cleanup, memory extraction, and greeting tasks.
func (s *AppService) Start(ctx context.Context) {
	if s == nil || s.engine == nil {
		return
	}
	s.engine.StartCleanup(ctx)
	s.engine.StartMemoryExtractionWorker(ctx)
	s.engine.StartGreetingTicker(ctx)
}

// Stop 停止后台任务。
func (s *AppService) Stop() {
	if s == nil || s.engine == nil {
		return
	}
	s.engine.StopCleanup()
	s.engine.StopGreetingTicker()
	s.engine.StopMemoryExtractionWorker()
}
