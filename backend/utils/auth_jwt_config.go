package utils

import (
	"errors"
	"strings"
	"sync"
	"time"
)

const (
	defaultAccessExpireSeconds = 432000 // 5 天，与 api Auth.AccessExpire 默认一致
)

var (
	jwtCfgMu  sync.RWMutex
	jwtSecret []byte
	jwtExpire = defaultAccessExpireSeconds * time.Second
	jwtReady  bool
)

// ConfigureJWT 在进程启动时设置 JWT 密钥与有效期（API / RPC 各调用一次即可）。
func ConfigureJWT(secret string, expireSeconds int64) error {
	secret = strings.TrimSpace(secret)
	if secret == "" {
		return errors.New("jwt access secret is empty")
	}
	jwtCfgMu.Lock()
	defer jwtCfgMu.Unlock()
	jwtSecret = []byte(secret)
	if expireSeconds > 0 {
		jwtExpire = time.Duration(expireSeconds) * time.Second
	} else {
		jwtExpire = defaultAccessExpireSeconds * time.Second
	}
	jwtReady = true
	return nil
}

func jwtSigningKey() ([]byte, error) {
	jwtCfgMu.RLock()
	defer jwtCfgMu.RUnlock()
	if !jwtReady || len(jwtSecret) == 0 {
		return nil, errors.New("jwt not configured: set auth.access_secret in backend/config/config.yaml")
	}
	return jwtSecret, nil
}
