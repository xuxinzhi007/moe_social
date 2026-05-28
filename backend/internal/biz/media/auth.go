package mediabiz

import (
	"fmt"
	"net/http"
	"regexp"
	"strings"

	"backend/utils"
)

var reSafeName = regexp.MustCompile(`[^a-zA-Z0-9_-]+`)

// ParseClaimsFromRequest 从 Header 或 query token 解析 JWT。
func ParseClaimsFromRequest(r *http.Request) (*utils.CustomClaims, error) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		auth := strings.TrimSpace(r.Header.Get("Authorization"))
		if strings.HasPrefix(auth, "Bearer ") {
			token = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
		}
	}
	if token == "" {
		return nil, fmt.Errorf("unauthorized")
	}
	claims, err := utils.ParseToken(token)
	if err != nil {
		return nil, fmt.Errorf("unauthorized")
	}
	return claims, nil
}

// FolderNameForUser 生成用户图片目录名。
func FolderNameForUser(userID uint, username string) string {
	name := strings.TrimSpace(username)
	if name == "" {
		name = "user"
	}
	name = reSafeName.ReplaceAllString(name, "_")
	name = strings.Trim(name, "_-")
	if name == "" {
		name = "user"
	}
	return fmt.Sprintf("%d_%s", userID, name)
}

// SplitImageKey 解析图片 key（folder__filename）。
func SplitImageKey(key string) (folder string, filename string, ok bool) {
	key = strings.TrimSpace(key)
	parts := strings.SplitN(key, "__", 2)
	if len(parts) != 2 {
		return "", "", false
	}
	folder = strings.TrimSpace(parts[0])
	filename = strings.TrimSpace(parts[1])
	if folder == "" || filename == "" {
		return "", "", false
	}
	return folder, filename, true
}
