package websocket

import (
	"sync"
	"time"

	"github.com/zeromicro/go-zero/core/logx"
)

// RateLimiter 速率限制器接口
type RateLimiter interface {
	Allow(userID string) bool
	Reset(userID string)
}

// TokenBucketRateLimiter 令牌桶速率限制器
type TokenBucketRateLimiter struct {
	mu           sync.RWMutex
	users        map[string]*tokenBucket
	capacity     int           // 令牌桶容量
	refillRate   int           // 每秒填充令牌数
	refillPeriod time.Duration // 填充周期
}

// tokenBucket 令牌桶
type tokenBucket struct {
	tokens      int
	lastRefill  time.Time
	capacity    int
	refillRate  int
	lastRequest time.Time
}

// NewRateLimiter 创建一个新的速率限制器
func NewRateLimiter(capacity, refillRate int, refillPeriod time.Duration) *TokenBucketRateLimiter {
	return &TokenBucketRateLimiter{
		users:        make(map[string]*tokenBucket),
		capacity:     capacity,
		refillRate:   refillRate,
		refillPeriod: refillPeriod,
	}
}

// DefaultRateLimiter 全局默认速率限制器
var DefaultRateLimiter = NewRateLimiter(100, 10, time.Second)

// Allow 检查是否允许请求
func (rl *TokenBucketRateLimiter) Allow(userID string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	// 获取或创建用户的令牌桶
	bucket, ok := rl.users[userID]
	if !ok {
		bucket = &tokenBucket{
			tokens:     rl.capacity,
			lastRefill: time.Now(),
			capacity:   rl.capacity,
			refillRate: rl.refillRate,
		}
		rl.users[userID] = bucket
	}

	// 填充令牌
	rl.refillTokens(bucket)

	// 检查是否有足够的令牌
	if bucket.tokens > 0 {
		bucket.tokens--
		bucket.lastRequest = time.Now()
		return true
	}

	return false
}

// refillTokens 填充令牌
func (rl *TokenBucketRateLimiter) refillTokens(bucket *tokenBucket) {
	now := time.Now()
	timeSinceLastRefill := now.Sub(bucket.lastRefill)

	// 计算应该填充的令牌数
	tokensToAdd := int(timeSinceLastRefill / rl.refillPeriod) * bucket.refillRate

	if tokensToAdd > 0 {
		bucket.tokens += tokensToAdd
		// 不超过容量
		if bucket.tokens > bucket.capacity {
			bucket.tokens = bucket.capacity
		}
		bucket.lastRefill = now
	}
}

// Reset 重置用户的速率限制
func (rl *TokenBucketRateLimiter) Reset(userID string) {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	delete(rl.users, userID)
	logx.Infof("Reset rate limiter for user %s", userID)
}

// CleanupInactiveUsers 清理不活跃的用户
func (rl *TokenBucketRateLimiter) CleanupInactiveUsers(maxInactiveTime time.Duration) {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	inactiveThreshold := now.Add(-maxInactiveTime)
	removed := 0

	for userID, bucket := range rl.users {
		if bucket.lastRequest.Before(inactiveThreshold) {
			delete(rl.users, userID)
			removed++
		}
	}

	if removed > 0 {
		logx.Infof("Cleaned up %d inactive users from rate limiter", removed)
	}
}

// ConnectionLimiter 连接限制器
type ConnectionLimiter struct {
	mu             sync.RWMutex
	userConnections map[string]int
	maxConnections  int
	globalLimit     int
}

// NewConnectionLimiter 创建一个新的连接限制器
func NewConnectionLimiter(maxConnections, globalLimit int) *ConnectionLimiter {
	return &ConnectionLimiter{
		userConnections: make(map[string]int),
		maxConnections:  maxConnections,
		globalLimit:     globalLimit,
	}
}

// DefaultConnectionLimiter 全局默认连接限制器
var DefaultConnectionLimiter = NewConnectionLimiter(10, 1000)

// Allow 检查是否允许新连接
func (cl *ConnectionLimiter) Allow(userID string) bool {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	// 检查全局连接数
	if len(cl.userConnections) >= cl.globalLimit {
		logx.Errorf("Global connection limit reached: %d", cl.globalLimit)
		return false
	}

	// 检查用户连接数
	if count, ok := cl.userConnections[userID]; ok && count >= cl.maxConnections {
		logx.Errorf("User connection limit reached for %s: %d", userID, cl.maxConnections)
		return false
	}

	// 增加用户连接数
	cl.userConnections[userID]++
	logx.Infof("Allowed new connection for user %s, current count: %d", userID, cl.userConnections[userID])
	return true
}

// Release 释放用户连接
func (cl *ConnectionLimiter) Release(userID string) {
	cl.mu.Lock()
	defer cl.mu.Unlock()

	if count, ok := cl.userConnections[userID]; ok {
		count--
		if count <= 0 {
			delete(cl.userConnections, userID)
			logx.Infof("Released all connections for user %s", userID)
		} else {
			cl.userConnections[userID] = count
			logx.Infof("Released connection for user %s, remaining: %d", userID, count)
		}
	}
}

// GetUserConnectionCount 获取用户连接数
func (cl *ConnectionLimiter) GetUserConnectionCount(userID string) int {
	cl.mu.RLock()
	defer cl.mu.RUnlock()

	if count, ok := cl.userConnections[userID]; ok {
		return count
	}

	return 0
}

// GetGlobalConnectionCount 获取全局连接数
func (cl *ConnectionLimiter) GetGlobalConnectionCount() int {
	cl.mu.RLock()
	defer cl.mu.RUnlock()

	return len(cl.userConnections)
}

// IPBasedLimiter IP-based限制器
type IPBasedLimiter struct {
	mu           sync.RWMutex
	ipConnections map[string]int
	maxConnections int
}

// NewIPBasedLimiter 创建一个新的IP-based限制器
func NewIPBasedLimiter(maxConnections int) *IPBasedLimiter {
	return &IPBasedLimiter{
		ipConnections: make(map[string]int),
		maxConnections: maxConnections,
	}
}

// DefaultIPBasedLimiter 全局默认IP-based限制器
var DefaultIPBasedLimiter = NewIPBasedLimiter(5)

// Allow 检查是否允许来自IP的新连接
func (il *IPBasedLimiter) Allow(ip string) bool {
	il.mu.Lock()
	defer il.mu.Unlock()

	// 检查IP连接数
	if count, ok := il.ipConnections[ip]; ok && count >= il.maxConnections {
		logx.Errorf("IP connection limit reached for %s: %d", ip, il.maxConnections)
		return false
	}

	// 增加IP连接数
	il.ipConnections[ip]++
	logx.Infof("Allowed new connection from IP %s, current count: %d", ip, il.ipConnections[ip])
	return true
}

// Release 释放IP连接
func (il *IPBasedLimiter) Release(ip string) {
	il.mu.Lock()
	defer il.mu.Unlock()

	if count, ok := il.ipConnections[ip]; ok {
		count--
		if count <= 0 {
			delete(il.ipConnections, ip)
			logx.Infof("Released all connections for IP %s", ip)
		} else {
			il.ipConnections[ip] = count
			logx.Infof("Released connection for IP %s, remaining: %d", ip, count)
		}
	}
}

// GetIPConnectionCount 获取IP连接数
func (il *IPBasedLimiter) GetIPConnectionCount(ip string) int {
	il.mu.RLock()
	defer il.mu.RUnlock()

	if count, ok := il.ipConnections[ip]; ok {
		return count
	}

	return 0
}

// CleanupInactiveIPs 清理不活跃的IP
func (il *IPBasedLimiter) CleanupInactiveIPs() {
	// 这里可以添加清理逻辑，例如定期清理长时间没有活动的IP
}
