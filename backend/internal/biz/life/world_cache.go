package lifebiz

import (
	"sync"

	"backend/model"
)

// WorldSnapshot is the in-memory simulation state for one world.
type WorldSnapshot struct {
	World     model.LifeWorld
	Entities  map[uint]*model.LifeEntity
	Grid      *WorldGrid
	Summary   WorldSummary
	TickCount int64
}

// WorldCache stores world snapshots safely across goroutines.
type WorldCache struct {
	mu     sync.RWMutex
	worlds map[string]*WorldSnapshot
}

// NewWorldCache creates a world cache.
func NewWorldCache() *WorldCache {
	return &WorldCache{
		worlds: make(map[string]*WorldSnapshot),
	}
}

// Get returns a snapshot for one world.
func (c *WorldCache) Get(worldID string) *WorldSnapshot {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.worlds[worldID]
}

// Set updates a snapshot for one world.
func (c *WorldCache) Set(worldID string, snap *WorldSnapshot) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.worlds[worldID] = snap
}

// GetEntity returns one entity inside a world snapshot.
func (c *WorldCache) GetEntity(worldID string, entityID uint) *model.LifeEntity {
	c.mu.RLock()
	defer c.mu.RUnlock()
	snap, ok := c.worlds[worldID]
	if !ok {
		return nil
	}
	return snap.Entities[entityID]
}
