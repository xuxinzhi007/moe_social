package lifeapp

import (
	"context"
	"time"

	"gorm.io/gorm"

	lifebiz "backend/internal/biz/life"
	lifedata "backend/internal/data/life"
)

// Config holds life engine configuration.
type Config struct {
	TickInterval int // seconds
}

// AppService is the life domain application service.
type AppService struct {
	db     *gorm.DB
	config Config
	engine *lifebiz.LifeEngine
	store  lifebiz.Store
	hub    *lifebiz.LifeWSHub
}

// New creates a new life AppService.
func New(db *gorm.DB, config Config) *AppService {
	store := lifedata.NewStore(db)
	cfg := lifebiz.DefaultConfig()
	if config.TickInterval > 0 {
		cfg.TickInterval = time.Duration(config.TickInterval) * time.Second
	}

	s := &AppService{db: db, config: config, store: store}

	// 创建 WS hub
	hub := lifebiz.NewLifeWSHub()
	s.hub = hub

	// 创建引擎（broadcastFn 由 hub 提供）
	engine := lifebiz.NewLifeEngine(store, cfg, hub.BroadcastState)
	s.engine = engine

	// 将引擎注入 hub，供 subscribe 时发送世界快照
	hub.SetEngine(engine)

	// 启动引擎
	// TODO: 当前使用 context.Background() 与 StartWorldRunner 模式保持一致，
	// 后续应传入可取消 context（例如从 ServiceContext 生命周期派生），以支持优雅关闭。
	lifebiz.StartLifeEngine(context.Background(), engine)

	return s
}

// Engine 暴露引擎供外部访问
func (s *AppService) Engine() *lifebiz.LifeEngine { return s.engine }

// Hub 暴露 WS hub 供 transport 层使用
func (s *AppService) Hub() *lifebiz.LifeWSHub { return s.hub }

// Store 暴露 store
func (s *AppService) Store() lifebiz.Store { return s.store }
