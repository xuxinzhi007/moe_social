package lifebiz

import (
	"context"
	"sync"
	"time"

	"backend/internal/platform/moelog"
)

// BroadcastFunc 广播回调类型
type BroadcastFunc func(msg TickBroadcast)

// LifeEngine 数字生命引擎
type LifeEngine struct {
	store       Store
	cache       *WorldCache
	persistence *PersistenceWriter
	config      LifeConfig
	broadcastMu sync.RWMutex
	broadcastFn BroadcastFunc
}

// NewLifeEngine 创建数字生命引擎
func NewLifeEngine(store Store, config LifeConfig, broadcastFn BroadcastFunc) *LifeEngine {
	engine := &LifeEngine{
		store:       store,
		cache:       NewWorldCache(),
		persistence: NewPersistenceWriter(store, config),
		config:      config,
		broadcastFn: broadcastFn,
	}
	return engine
}

// StartLifeEngine 启动引擎 goroutine
func StartLifeEngine(ctx context.Context, e *LifeEngine) {
	// 启动持久化写入器
	e.persistence.Start(ctx)

	go func() {
		defer func() {
			if r := recover(); r != nil {
				moelog.Errorf("life: LifeEngine panic recovered: %v", r)
			}
		}()
		ticker := time.NewTicker(e.config.TickInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				moelog.Infof("life: engine stopped for world %q", e.config.WorldName)
				return
			case <-ticker.C:
				tickCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
				RunLifeTick(tickCtx, e)
				cancel()
			}
		}
	}()
}

// SetBroadcastFunc 注入广播回调（可在运行时由 WS hub 注入）
func (e *LifeEngine) SetBroadcastFunc(fn BroadcastFunc) {
	e.broadcastMu.Lock()
	defer e.broadcastMu.Unlock()
	e.broadcastFn = fn
}

// GetWorldCache 暴露缓存供外部读取
func (e *LifeEngine) GetWorldCache() *WorldCache { return e.cache }

// GetConfig 获取配置
func (e *LifeEngine) GetConfig() LifeConfig { return e.config }
