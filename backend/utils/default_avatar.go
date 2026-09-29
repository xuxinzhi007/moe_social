package utils

import (
	"fmt"
	"net/url"
	"strings"
)

const picsumHost = "picsum.photos"

// StableDefaultAvatar 为用户生成稳定且互不重复的默认头像地址。
// Picsum 的 seed 对同一字符串始终返回同一张图，用户 ID 保证种子不碰撞。
func StableDefaultAvatar(userID uint) string {
	if userID == 0 {
		return ""
	}
	return fmt.Sprintf("https://picsum.photos/seed/moe-%d/150", userID)
}

// NeedsStableDefaultAvatar 判断头像是否还没固定。
// 空值，以及不带 seed 的 picsum 地址，每次打开都会换图。
func NeedsStableDefaultAvatar(raw string) bool {
	value := strings.TrimSpace(raw)
	if value == "" {
		return true
	}
	parsed, err := url.Parse(value)
	if err != nil || parsed.Host == "" {
		return false
	}
	host := strings.ToLower(parsed.Hostname())
	if host != picsumHost && host != "www."+picsumHost {
		return false
	}
	return !strings.Contains(parsed.Path, "/seed/")
}

// ResolveUserAvatar 展示时把未固定的默认头像换成该用户的稳定地址。
// 用户自己上传或已带 seed 的地址保持原样。
func ResolveUserAvatar(userID uint, stored string) string {
	stored = strings.TrimSpace(stored)
	if !NeedsStableDefaultAvatar(stored) {
		return stored
	}
	return StableDefaultAvatar(userID)
}
