package gamebiz

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"sync"
	"time"
)

// dialogueCache LLM 对话缓存（进程内 LRU，仅缓存模板/条件对话，不缓存开放 LLM 对话）。
type dialogueCache struct {
	mu      sync.Mutex
	items   map[string]*cacheEntry
	order   []string // LRU 淘汰顺序（头部最旧）
	maxSize int
	ttl     time.Duration
}

type cacheEntry struct {
	response  turnLLMOutput
	source    string
	createdAt time.Time
}

// globalDialogueCache 全局对话缓存实例。
var globalDialogueCache = newDialogueCache(200, 5*time.Minute)

func newDialogueCache(maxSize int, ttl time.Duration) *dialogueCache {
	return &dialogueCache{
		items:   make(map[string]*cacheEntry),
		order:   make([]string, 0, maxSize),
		maxSize: maxSize,
		ttl:     ttl,
	}
}

// dialogueCacheKey 计算对话缓存 key。
// 仅对模板类对话和条件对话缓存，参数包括 scene + npc + action 摘要 + flags 关键状态。
func dialogueCacheKey(sceneName, npcName, action string, flags WorldFlags) string {
	// 取 action 前 80 字符作为摘要
	actionSummary := action
	if len([]rune(actionSummary)) > 80 {
		actionSummary = string([]rune(actionSummary)[:80])
	}
	raw := fmt.Sprintf("%s|%s|%s|%d|%s|%s",
		sceneName, npcName, actionSummary,
		flags.StoryPhase, flags.PlayerFocus, flags.WorldMood,
	)
	h := sha256.Sum256([]byte(raw))
	return fmt.Sprintf("%x", h[:16])
}

// get 获取缓存，命中则将其移到最新位置，未命中或过期返回 false。
func (c *dialogueCache) get(key string) (turnLLMOutput, string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	entry, ok := c.items[key]
	if !ok {
		return turnLLMOutput{}, "", false
	}
	if time.Since(entry.createdAt) > c.ttl {
		// 过期，惰性删除
		delete(c.items, key)
		c.removeFromOrder(key)
		return turnLLMOutput{}, "", false
	}
	// 命中，移到最新位置
	c.touchLocked(key)
	return entry.response, entry.source, true
}

// put 写入缓存，超出上限时淘汰最旧的。
func (c *dialogueCache) put(key string, response turnLLMOutput, source string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, ok := c.items[key]; ok {
		c.items[key] = &cacheEntry{response: response, source: source, createdAt: time.Now()}
		c.touchLocked(key)
		return
	}
	// 淘汰最旧
	for len(c.order) >= c.maxSize && len(c.order) > 0 {
		oldest := c.order[0]
		c.order = c.order[1:]
		delete(c.items, oldest)
	}
	c.items[key] = &cacheEntry{response: response, source: source, createdAt: time.Now()}
	c.order = append(c.order, key)
}

func (c *dialogueCache) touchLocked(key string) {
	for i, k := range c.order {
		if k == key {
			c.order = append(c.order[:i], c.order[i+1:]...)
			c.order = append(c.order, key)
			return
		}
	}
	// key 不在 order 中（可能被惰性删除后重新 put），添加
	c.order = append(c.order, key)
}

func (c *dialogueCache) removeFromOrder(key string) {
	for i, k := range c.order {
		if k == key {
			c.order = append(c.order[:i], c.order[i+1:]...)
			return
		}
	}
}

// isDialogueCacheEligible 判断对话类型是否适合缓存。
// 仅模板类对话（dialogue_condition）和对话开场（dialogue_fallback 的模板部分）可缓存，
// 开放 LLM 对话（dialogue_llm）不缓存（上下文每次不同）。
func isDialogueCacheEligible(source string) bool {
	switch source {
	case "dialogue_condition", "dialogue_fallback":
		return true
	default:
		return false
	}
}

// normalizeDialogueSource 将 source 字符串规范化用于缓存判断。
func normalizeDialogueSource(src string) string {
	return strings.TrimSpace(src)
}
