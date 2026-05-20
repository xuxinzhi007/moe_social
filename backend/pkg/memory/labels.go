package memory

import (
	"strings"
	"unicode"
)

// CategoryLabel 将 memory_type / key 映射为展示分类。
func CategoryLabel(memoryType, key string) string {
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

// TitleFromKey 将 key 转为展示标题。
func TitleFromKey(key string) string {
	k := strings.TrimSpace(key)
	if k == "" {
		return "记忆"
	}
	known := map[string]string{
		"user_name": "称呼", "nickname": "昵称", "name": "名字",
		"hobby": "爱好", "hobbies": "爱好", "profession": "职业", "job": "职业",
		"location": "所在地", "city": "城市", "age": "年龄", "birthday": "生日",
		"preference": "偏好", "relationship": "关系", "persona": "人设", "style": "交流风格",
		"user_nickname": "昵称",
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
