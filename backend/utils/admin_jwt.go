package utils

import (
	"errors"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/spf13/viper"
)

const defaultAdminExpireHours = 24

var (
	adminJWTMu     sync.RWMutex
	adminJWTSecret []byte
	adminJWTExpire = defaultAdminExpireHours * time.Hour
	adminJWTReady  bool
)

// AdminClaims Moe Admin JWT。
type AdminClaims struct {
	AdminID  uint   `json:"admin_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// ConfigureAdminJWT 配置管理员 JWT（与 App JWT 密钥分离）。
func ConfigureAdminJWT(secret string, expireHours int64) error {
	secret = strings.TrimSpace(secret)
	if secret == "" {
		return errors.New("admin jwt secret is empty")
	}
	adminJWTMu.Lock()
	defer adminJWTMu.Unlock()
	adminJWTSecret = []byte(secret)
	if expireHours > 0 {
		adminJWTExpire = time.Duration(expireHours) * time.Hour
	} else {
		adminJWTExpire = defaultAdminExpireHours * time.Hour
	}
	adminJWTReady = true
	return nil
}

// LoadAdminJWTFromViper 从 config.yaml 加载 admin.jwt_secret。
func LoadAdminJWTFromViper() error {
	secret := resolveAdminJWTSecret()
	if secret == "" {
		return errors.New("admin.jwt_secret 未配置")
	}
	hours := viper.GetInt64("admin.token_expire_hours")
	if hours <= 0 {
		hours = defaultAdminExpireHours
	}
	return ConfigureAdminJWT(secret, hours)
}

func resolveAdminJWTSecret() string {
	if s := strings.TrimSpace(os.Getenv("MOE_ADMIN_JWT_SECRET")); s != "" {
		return s
	}
	return strings.TrimSpace(viper.GetString("admin.jwt_secret"))
}

func adminSigningKey() ([]byte, error) {
	adminJWTMu.RLock()
	defer adminJWTMu.RUnlock()
	if !adminJWTReady || len(adminJWTSecret) == 0 {
		return nil, errors.New("admin jwt not configured")
	}
	return adminJWTSecret, nil
}

// GenerateAdminToken 签发管理员 Token。
func GenerateAdminToken(adminID uint, username, role string) (string, time.Time, error) {
	key, err := adminSigningKey()
	if err != nil {
		return "", time.Time{}, err
	}
	exp := time.Now().Add(adminJWTExpire)
	claims := AdminClaims{
		AdminID:  adminID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(exp),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(key)
	return signed, exp, err
}

// ParseAdminToken 解析管理员 Token。
func ParseAdminToken(tokenString string) (*AdminClaims, error) {
	key, err := adminSigningKey()
	if err != nil {
		return nil, err
	}
	token, err := jwt.ParseWithClaims(tokenString, &AdminClaims{}, func(token *jwt.Token) (interface{}, error) {
		return key, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*AdminClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid admin token")
	}
	return claims, nil
}
