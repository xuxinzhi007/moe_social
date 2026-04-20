package utils

import (
	"sync"
	"time"
)

// ModelCache 模型缓存
type ModelCache struct {
	models    []string
	timestamp time.Time
	mutex     sync.RWMutex
	TTL       time.Duration
}

// NewModelCache 创建一个新的模型缓存
func NewModelCache() *ModelCache {
	return &ModelCache{
		TTL: 5 * time.Minute, // 缓存5分钟
	}
}

// Get 获取缓存的模型列表
func (c *ModelCache) Get() ([]string, bool) {
	c.mutex.RLock()
	defer c.mutex.RUnlock()

	if len(c.models) == 0 || time.Since(c.timestamp) > c.TTL {
		return nil, false
	}

	return c.models, true
}

// Set 设置模型列表到缓存
func (c *ModelCache) Set(models []string) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.models = models
	c.timestamp = time.Now()
}

// Clear 清空缓存
func (c *ModelCache) Clear() {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.models = nil
	c.timestamp = time.Time{}
}
