package utils

import (
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// AdminMediaImage 云图库文件条目（Admin 治理用）。
type AdminMediaImage struct {
	Filename    string
	FileName    string
	OwnerFolder string
	MediaKind   string
	URL         string
	Size        int64
	CreatedAt   string
	OwnerHint   string
}

// AdminMediaOwnerSummary 按用户目录聚合的图库统计。
type AdminMediaOwnerSummary struct {
	OwnerFolder  string
	UserID       string
	UsernameHint string
	FileCount    int
	TotalBytes   int64
}

// ListAdminMediaImages 递归扫描本地图片目录，支持按用户目录/类型/关键字过滤与分页。
func ListAdminMediaImages(localDir, publicBase string, page, pageSize int, keyword, ownerFolder, mediaKind string) ([]AdminMediaImage, []AdminMediaOwnerSummary, int, error) {
	imgDir := strings.TrimSpace(localDir)
	if imgDir == "" {
		imgDir = "./data/images"
	}
	base := strings.TrimRight(strings.TrimSpace(publicBase), "/")
	if base == "" {
		base = "http://localhost:8888"
	}
	kw := strings.ToLower(strings.TrimSpace(keyword))
	ownerFilter := strings.TrimSpace(ownerFolder)
	kindFilter := strings.ToLower(strings.TrimSpace(mediaKind))

	all, err := scanAdminMediaImages(imgDir, base)
	if err != nil {
		if os.IsNotExist(err) {
			return []AdminMediaImage{}, []AdminMediaOwnerSummary{}, 0, nil
		}
		return nil, nil, 0, err
	}

	owners := summarizeAdminMediaOwners(all)
	filtered := make([]AdminMediaImage, 0, len(all))
	for _, item := range all {
		if ownerFilter != "" && item.OwnerFolder != ownerFilter {
			continue
		}
		if kw != "" && !adminMediaMatchesKeyword(item, kw) {
			continue
		}
		if kindFilter != "" && item.MediaKind != kindFilter {
			continue
		}
		filtered = append(filtered, item)
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].CreatedAt > filtered[j].CreatedAt
	})
	total := len(filtered)
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 30
	}
	start := (page - 1) * pageSize
	if start > total {
		start = total
	}
	end := start + pageSize
	if end > total {
		end = total
	}
	if start >= end {
		return []AdminMediaImage{}, owners, total, nil
	}
	return filtered[start:end], owners, total, nil
}

func scanAdminMediaImages(imgDir, base string) ([]AdminMediaImage, error) {
	all := make([]AdminMediaImage, 0, 64)
	err := filepath.WalkDir(imgDir, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(imgDir, path)
		if err != nil {
			return nil
		}
		rel = filepath.ToSlash(rel)
		if rel == "" || rel == "." || strings.HasPrefix(rel, "..") {
			return nil
		}
		key, folder, fileName, ok := adminMediaStorageParts(rel)
		if !ok {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		all = append(all, AdminMediaImage{
			Filename:    key,
			FileName:    fileName,
			OwnerFolder: folder,
			MediaKind:   ClassifyAdminMediaKind(fileName),
			URL:         fmt.Sprintf("%s/api/images/%s", base, url.PathEscape(key)),
			Size:        info.Size(),
			CreatedAt:   info.ModTime().Format(time.DateTime),
			OwnerHint:   parseImageOwnerHint(key),
		})
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(all, func(i, j int) bool {
		return all[i].CreatedAt > all[j].CreatedAt
	})
	return all, nil
}

func summarizeAdminMediaOwners(all []AdminMediaImage) []AdminMediaOwnerSummary {
	type agg struct {
		summary AdminMediaOwnerSummary
	}
	byFolder := map[string]*agg{}
	for _, item := range all {
		if item.OwnerFolder == "" {
			continue
		}
		entry, ok := byFolder[item.OwnerFolder]
		if !ok {
			userID, username := parseOwnerFolder(item.OwnerFolder)
			entry = &agg{
				summary: AdminMediaOwnerSummary{
					OwnerFolder:  item.OwnerFolder,
					UserID:       userID,
					UsernameHint: username,
				},
			}
			byFolder[item.OwnerFolder] = entry
		}
		entry.summary.FileCount++
		entry.summary.TotalBytes += item.Size
	}
	out := make([]AdminMediaOwnerSummary, 0, len(byFolder))
	for _, entry := range byFolder {
		out = append(out, entry.summary)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].FileCount != out[j].FileCount {
			return out[i].FileCount > out[j].FileCount
		}
		return out[i].OwnerFolder < out[j].OwnerFolder
	})
	return out
}

func adminMediaMatchesKeyword(item AdminMediaImage, kw string) bool {
	for _, part := range []string{
		item.Filename,
		item.FileName,
		item.OwnerFolder,
		item.OwnerHint,
		item.MediaKind,
	} {
		if strings.Contains(strings.ToLower(part), kw) {
			return true
		}
	}
	return false
}

// ClassifyAdminMediaKind 根据文件名推断来源（均落在 Image.LocalDir，与 App 云图库同一目录）。
func ClassifyAdminMediaKind(fileName string) string {
	lower := strings.ToLower(strings.TrimSpace(fileName))
	switch {
	case strings.Contains(lower, "hand_draw_thumb"):
		return "hand_draw"
	case strings.Contains(lower, "avatar"):
		return "avatar"
	default:
		return "gallery"
	}
}

// DeleteAdminMediaImage 删除云图库中的单个文件（filename 为 storage key：userFolder__file）。
func DeleteAdminMediaImage(localDir, filename string) error {
	key := strings.TrimSpace(filename)
	if key == "" || key == "." || strings.Contains(key, "..") || strings.Contains(key, "/") || strings.Contains(key, "\\") {
		return fmt.Errorf("invalid filename")
	}
	imgDir := strings.TrimSpace(localDir)
	if imgDir == "" {
		imgDir = "./data/images"
	}
	target, err := adminMediaFilePath(imgDir, key)
	if err != nil {
		return err
	}
	if err := os.Remove(target); err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("图片不存在")
		}
		return err
	}
	return nil
}

func adminMediaStorageParts(rel string) (key, folder, fileName string, ok bool) {
	rel = strings.TrimSpace(filepath.ToSlash(rel))
	if rel == "" || rel == "." || strings.HasPrefix(rel, "..") {
		return "", "", "", false
	}
	if strings.Contains(rel, "/") {
		parts := strings.Split(rel, "/")
		if len(parts) != 2 {
			return "", "", "", false
		}
		folder = strings.TrimSpace(parts[0])
		fileName = strings.TrimSpace(parts[1])
		if folder == "" || fileName == "" || fileName == "." {
			return "", "", "", false
		}
		return folder + "__" + fileName, folder, fileName, true
	}
	if strings.Contains(rel, "__") {
		folder, fileName, ok = splitAdminMediaStorageKey(rel)
		if !ok {
			return "", "", "", false
		}
		return rel, folder, fileName, true
	}
	return "", "", "", false
}

func adminMediaFilePath(imgDir, key string) (string, error) {
	folder, file, ok := splitAdminMediaStorageKey(key)
	if !ok {
		return "", fmt.Errorf("invalid filename")
	}
	folder = filepath.Base(folder)
	file = filepath.Base(file)
	if folder == "" || file == "" {
		return "", fmt.Errorf("invalid filename")
	}
	target := filepath.Join(imgDir, folder, file)
	absDir, err := filepath.Abs(imgDir)
	if err != nil {
		return "", err
	}
	absTarget, err := filepath.Abs(target)
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(absTarget, absDir+string(os.PathSeparator)) && absTarget != absDir {
		return "", fmt.Errorf("invalid filename")
	}
	return target, nil
}

func splitAdminMediaStorageKey(key string) (folder string, filename string, ok bool) {
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

func parseOwnerFolder(folder string) (userID, username string) {
	folder = strings.TrimSpace(folder)
	if idx := strings.Index(folder, "_"); idx > 0 {
		prefix := folder[:idx]
		if isDigits(prefix) {
			return prefix, folder[idx+1:]
		}
	}
	return "", folder
}

func parseImageOwnerHint(key string) string {
	folder, _, ok := splitAdminMediaStorageKey(key)
	if !ok {
		return ""
	}
	userID, username := parseOwnerFolder(folder)
	if userID != "" && username != "" {
		return fmt.Sprintf("user_id=%s · %s", userID, username)
	}
	if userID != "" {
		return "user_id=" + userID
	}
	return folder
}

func isDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}
