package utils

import (
	"errors"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/spf13/viper"
)

const (
	envAuthAccessSecret        = "MOE_AUTH_ACCESS_SECRET"
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

// LoadJWTFromViper 从已 InitConfig 的 viper 与环境变量加载 JWT（RPC 使用）。
func LoadJWTFromViper() error {
	secret := resolveAuthAccessSecret()
	expire := viper.GetInt64("auth.access_expire_seconds")
	if expire <= 0 {
		expire = defaultAccessExpireSeconds
	}
	return ConfigureJWT(secret, expire)
}

// ResolveAuthAccessSecret 统一解析 JWT 密钥：环境变量 > config.yaml。
func ResolveAuthAccessSecret() string {
	return resolveAuthAccessSecret()
}

func resolveAuthAccessSecret() string {
	if s := strings.TrimSpace(os.Getenv(envAuthAccessSecret)); s != "" {
		return s
	}
	return strings.TrimSpace(viper.GetString("auth.access_secret"))
}

func jwtSigningKey() ([]byte, error) {
	jwtCfgMu.RLock()
	defer jwtCfgMu.RUnlock()
	if !jwtReady || len(jwtSecret) == 0 {
		return nil, errors.New("jwt not configured: set auth.access_secret in backend/config/config.yaml")
	}
	return jwtSecret, nil
}
