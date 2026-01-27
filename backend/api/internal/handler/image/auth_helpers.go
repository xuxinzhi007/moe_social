package image

import (
	"fmt"
	"net/http"
	"regexp"
	"strings"

	"backend/utils"
)

var reSafeName = regexp.MustCompile(`[^a-zA-Z0-9_-]+`)

func getTokenFromRequest(r *http.Request) string {
	// WebSocket 用 query token；HTTP 也允许 query token（Web 端图片请求不方便带 header）
	q := strings.TrimSpace(r.URL.Query().Get("token"))
	if q != "" {
		return q
	}

	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	return ""
}

func mustParseClaims(r *http.Request) (*utils.CustomClaims, error) {
	token := getTokenFromRequest(r)
	if token == "" {
		return nil, fmt.Errorf("unauthorized")
	}
	claims, err := utils.ParseToken(token)
	if err != nil {
		return nil, fmt.Errorf("unauthorized")
	}
	return claims, nil
}

func folderNameForUser(userID uint, username string) string {
	name := strings.TrimSpace(username)
	if name == "" {
		name = "user"
	}
	name = reSafeName.ReplaceAllString(name, "_")
	name = strings.Trim(name, "_-")
	if name == "" {
		name = "user"
	}
	// 用 userId 防止重名 + 方便稳定定位
	return fmt.Sprintf("%d_%s", userID, name)
}

func splitImageKey(key string) (folder string, filename string, ok bool) {
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

