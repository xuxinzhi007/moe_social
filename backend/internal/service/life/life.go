package lifeapp

import (
	"context"
	"sync"
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

	// 生命周期管理
	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

// New creates a new life AppService.
func New(db *gorm.DB, config Config) *AppService {
	store := lifedata.NewStore(db)
	cfg := lifebiz.DefaultConfig()
	if config.TickInterval > 0 {
		cfg.TickInterval = time.Duration(config.TickInterval) * time.Second
	}

	// 使用可取消的 context，支持优雅关闭
	ctx, cancel := context.WithCancel(context.Background())

	s := &AppService{
		db:     db,
		config: config,
		store:  store,
		ctx:    ctx,
		cancel: cancel,
	}

	// 创建 WS hub
	hub := lifebiz.NewLifeWSHub()
	s.hub = hub

	// 创建引擎（broadcastFn 由 hub 提供）
	engine := lifebiz.NewLifeEngine(store, cfg, hub.BroadcastState)
	s.engine = engine

	// 将引擎注入 hub，供 subscribe 时发送世界快照
	hub.SetEngine(engine)

	// 启动引擎（使用可取消 context，支持优雅关闭）
	lifebiz.StartLifeEngine(ctx, engine)

	return s
}

// Shutdown 优雅关闭：取消 context 并等待引擎和持久化 writer 完成最终 flush
func (s *AppService) Shutdown() {
	if s.cancel != nil {
		s.cancel()
	}
	s.wg.Wait()
}

// Engine 暴露引擎供外部访问
func (s *AppService) Engine() *lifebiz.LifeEngine { return s.engine }

// Hub 暴露 WS hub 供 transport 层使用
func (s *AppService) Hub() *lifebiz.LifeWSHub { return s.hub }

// Store 暴露 store
func (s *AppService) Store() lifebiz.Store { return s.store }
