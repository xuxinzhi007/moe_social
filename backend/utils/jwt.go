package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// CustomClaims 自定义JWT声明结构体
type CustomClaims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT Token
func GenerateToken(userID uint, username string) (string, error) {
	key, err := jwtSigningKey()
	if err != nil {
		return "", err
	}

	jwtCfgMu.RLock()
	expire := jwtExpire
	jwtCfgMu.RUnlock()

	claims := CustomClaims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expire)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(key)
}

// ParseToken 解析JWT Token
func ParseToken(tokenString string) (*CustomClaims, error) {
	key, err := jwtSigningKey()
	if err != nil {
		return nil, err
	}

	token, err := jwt.ParseWithClaims(tokenString, &CustomClaims{}, func(token *jwt.Token) (interface{}, error) {
		return key, nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*CustomClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// GetUserIDFromToken 从Token中获取用户ID
func GetUserIDFromToken(tokenString string) (uint, error) {
	claims, err := ParseToken(tokenString)
	if err != nil {
		return 0, err
	}

	return claims.UserID, nil
}
