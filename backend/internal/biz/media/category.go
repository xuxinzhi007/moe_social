package mediabiz

import (
	"fmt"
	"strings"
)

// 用户媒体在对象存储里的分类目录。
const (
	CategoryAvatar = "avatar" // 头像
	CategoryAlbum  = "album"  // 云相册
	CategoryPost   = "post"   // 帖子
	CategoryChat   = "chat"   // 私信
)

// NormalizeCategory 把上传分类收成 avatar、album、post、chat。空值视为 album。
// 中文别名会收成对应英文目录，避免对象键里出现中文。
func NormalizeCategory(raw string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", CategoryAlbum, "相册", "云相册":
		return CategoryAlbum, nil
	case CategoryAvatar, "头像":
		return CategoryAvatar, nil
	case CategoryPost, "帖子":
		return CategoryPost, nil
	case CategoryChat, "私信":
		return CategoryChat, nil
	default:
		return "", fmt.Errorf("unknown media category %q", raw)
	}
}

// StorageFolder 拼出「用户目录/分类」。分类为空时保持旧的单层目录。
func StorageFolder(userFolder, category string) string {
	userFolder = cleanFolder(userFolder)
	category = strings.TrimSpace(category)
	if userFolder == "" || category == "" {
		return userFolder
	}
	return userFolder + "/" + category
}

// OwnedFolder 判断对象目录是否属于该用户（根目录或它下面的一个分类）。
func OwnedFolder(folder, userFolder string) bool {
	folder = cleanFolder(folder)
	userFolder = cleanFolder(userFolder)
	if folder == "" || userFolder == "" {
		return false
	}
	if folder == userFolder {
		return true
	}
	prefix := userFolder + "/"
	if !strings.HasPrefix(folder, prefix) {
		return false
	}
	category := strings.TrimPrefix(folder, prefix)
	if strings.Contains(category, "/") {
		return false
	}
	_, err := NormalizeCategory(category)
	return err == nil
}
