package lifebiz

import (
	"sync"

	"backend/model"
)

// WorldSnapshot 内存中的世界快照
type WorldSnapshot struct {
	World     model.LifeWorld
	Entities  map[uint]*model.LifeEntity // entityID -> entity（指针，方便就地修改）
	TickCount int64
}

// WorldCache 线程安全的世界缓存
type WorldCache struct {
	mu     sync.RWMutex
	worlds map[string]*WorldSnapshot // worldName -> snapshot
}

// NewWorldCache 创建新的世界缓存
func NewWorldCache() *WorldCache {
	return &WorldCache{
		worlds: make(map[string]*WorldSnapshot),
	}
}

// Get 获取世界快照（读锁）
func (c *WorldCache) Get(worldID string) *WorldSnapshot {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.worlds[worldID]
}

// Set 设置世界快照（写锁）
func (c *WorldCache) Set(worldID string, snap *WorldSnapshot) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.worlds[worldID] = snap
}

// GetEntity 获取指定世界中的实体（读锁）
func (c *WorldCache) GetEntity(worldID string, entityID uint) *model.LifeEntity {
	c.mu.RLock()
	defer c.mu.RUnlock()
	snap, ok := c.worlds[worldID]
	if !ok {
		return nil
	}
	return snap.Entities[entityID]
}
