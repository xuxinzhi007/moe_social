package user

import (
	"fmt"
	"strings"
	"unicode"

	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

// UserMemoryDisplayData 面向用户展示的记忆视图（不含技术字段与调试信息）。
type UserMemoryDisplayData struct {
	Headline string                    `json:"headline"`
	Profiles []UserMemoryDisplayProfile `json:"profiles"`
	Items    []UserMemoryDisplayItem    `json:"items"`
	Total    int                        `json:"total"`
}

type UserMemoryDisplayProfile struct {
	Title     string `json:"title"`
	Summary   string `json:"summary"`
	ItemCount int    `json:"item_count"`
}

type UserMemoryDisplayItem struct {
	ID        string `json:"id"`
	Key       string `json:"key"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Category  string `json:"category"`
	UpdatedAt string `json:"updated_at"`
}

func isTechnicalUserMemory(key, source string) bool {
	k := strings.ToLower(strings.TrimSpace(key))
	s := strings.ToLower(strings.TrimSpace(source))
	return strings.HasPrefix(k, "device_info:") || s == "device_sync"
}

func isNoiseMemoryValue(value string) bool {
	norm := strings.ToLower(strings.TrimSpace(value))
	if norm == "" {
		return true
	}
	switch norm {
	case "-", "--", "/", "n/a", "na", "none", "null", "nil", "unknown", "无", "未知", "未提及", "不知道":
		return true
	}
	return false
}

func memoryCategoryLabel(memoryType, key string) string {
	t := strings.ToLower(strings.TrimSpace(memoryType))
	switch t {
	case "preference":
		return "偏好"
	case "relationship":
		return "关系"
	case "persona", "identity", "profile":
		return "身份"
	case "plan":
		return "计划"
	case "style":
		return "风格"
	case "fact", "general", "":
		return "了解"
	default:
		k := strings.ToLower(key)
		if strings.Contains(k, "prefer") || strings.Contains(k, "爱好") || strings.Contains(k, "兴趣") {
			return "偏好"
		}
		if strings.Contains(k, "relation") || strings.Contains(k, "关系") {
			return "关系"
		}
		return "了解"
	}
}

func memoryTitleFromKey(key string) string {
	k := strings.TrimSpace(key)
	if k == "" {
		return "记忆"
	}
	known := map[string]string{
		"user_name":    "称呼",
		"nickname":     "昵称",
		"name":         "名字",
		"hobby":        "爱好",
		"hobbies":      "爱好",
		"profession":   "职业",
		"job":          "职业",
		"location":     "所在地",
		"city":         "城市",
		"age":          "年龄",
		"birthday":     "生日",
		"preference":   "偏好",
		"relationship": "关系",
		"persona":      "人设",
		"style":        "交流风格",
	}
	if title, ok := known[strings.ToLower(k)]; ok {
		return title
	}
	parts := strings.Split(k, "_")
	for i, p := range parts {
		if p == "" {
			continue
		}
		runes := []rune(p)
		runes[0] = unicode.ToUpper(runes[0])
		parts[i] = string(runes)
	}
	return strings.Join(parts, " ")
}

func profileTitleFromType(memoryType string) string {
	return memoryCategoryLabel(memoryType, "")
}

func BuildUserMemoryDisplay(memories []*super.UserMemory, profiles []*super.UserMemoryProfile) UserMemoryDisplayData {
	items := make([]UserMemoryDisplayItem, 0, len(memories))
	for _, m := range memories {
		if m == nil {
			continue
		}
		key := strings.TrimSpace(m.Key)
		value := strings.TrimSpace(m.Value)
		if key == "" || value == "" {
			continue
		}
		if isTechnicalUserMemory(key, m.Source) || isNoiseMemoryValue(value) {
			continue
		}
		mType := strings.TrimSpace(m.MemoryType)
		if mType == "" {
			mType = "fact"
		}
		items = append(items, UserMemoryDisplayItem{
			ID:        m.Id,
			Key:       key,
			Title:     memoryTitleFromKey(key),
			Content:   value,
			Category:  memoryCategoryLabel(mType, key),
			UpdatedAt: m.UpdatedAt,
		})
	}

	displayProfiles := make([]UserMemoryDisplayProfile, 0, len(profiles))
	for _, p := range profiles {
		if p == nil {
			continue
		}
		summary := strings.TrimSpace(p.Summary)
		if summary == "" {
			continue
		}
		displayProfiles = append(displayProfiles, UserMemoryDisplayProfile{
			Title:     profileTitleFromType(p.MemoryType),
			Summary:   summary,
			ItemCount: int(p.ItemCount),
		})
	}

	headline := fmt.Sprintf("AI 已记住 %d 条关于你的信息", len(items))
	if len(items) == 0 {
		headline = "继续聊天后，AI 会自动记住你的偏好与重要信息"
	}

	return UserMemoryDisplayData{
		Headline: headline,
		Profiles: displayProfiles,
		Items:    items,
		Total:    len(items),
	}
}

// BuildUserMemoryDisplayFromAPI 从 API types 构建（测试或聚合用）。
func BuildUserMemoryDisplayFromAPI(memories []types.UserMemory, profiles []types.UserMemoryProfile) UserMemoryDisplayData {
	rpcMem := make([]*super.UserMemory, 0, len(memories))
	for _, m := range memories {
		rpcMem = append(rpcMem, &super.UserMemory{
			Id: m.Id, Key: m.Key, Value: m.Value, MemoryType: m.MemoryType,
			Source: m.Source, UpdatedAt: m.UpdatedAt,
		})
	}
	rpcProf := make([]*super.UserMemoryProfile, 0, len(profiles))
	for _, p := range profiles {
		rpcProf = append(rpcProf, &super.UserMemoryProfile{
			MemoryType: p.MemoryType, Summary: p.Summary, ItemCount: int32(p.ItemCount),
		})
	}
	return BuildUserMemoryDisplay(rpcMem, rpcProf)
}
