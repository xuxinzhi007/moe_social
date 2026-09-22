package contentbiz

import (
	"errors"
	"strings"
)

// ErrUnsupportedContentType 不支持的内容类型。
var ErrUnsupportedContentType = errors.New("unsupported content type")

// ErrEmptyPrompt 内容生成提示词为空。
var ErrEmptyPrompt = errors.New("empty prompt")

// GenerateInput 内容生成请求。
type GenerateInput struct {
	UserID  string
	Type    string
	Prompt  string
	Options map[string]interface{}
}

// GenerateResult 内容生成结果。
type GenerateResult struct {
	ID        string
	Type      string
	URL       string
	Content   string
	CreatedAt string
}

// NormalizeGenerateInput trims user input and validates the content type.
func NormalizeGenerateInput(in GenerateInput) (GenerateInput, error) {
	in.UserID = strings.TrimSpace(in.UserID)
	in.Type = strings.TrimSpace(strings.ToLower(in.Type))
	in.Prompt = strings.TrimSpace(in.Prompt)
	if in.Prompt == "" {
		return GenerateInput{}, ErrEmptyPrompt
	}
	if _, ok := ContentSystemPrompt(in.Type); !ok {
		return GenerateInput{}, ErrUnsupportedContentType
	}
	return in, nil
}

// ContentSystemPrompt returns backend-owned generation policy for a content type.
func ContentSystemPrompt(contentType string) (string, bool) {
	switch strings.TrimSpace(strings.ToLower(contentType)) {
	case "text":
		return "你是一个专业的内容生成助手。根据用户需求生成高质量文本，结构清晰、语言自然，必要时主动补全标题、要点和结尾。", true
	case "image":
		return "你是一个专业的图像提示词助手。把用户想法整理为可用于图像生成的画面描述，包含主体、场景、风格、构图、光线、色彩和负面约束建议。", true
	case "video":
		return "你是一个专业的视频脚本助手。输出可拍摄或可生成的视频脚本，包含镜头顺序、画面、旁白、节奏、时长和转场建议。", true
	case "code":
		return "你是一个专业的代码助手。优先给出可运行、可读、边界明确的代码；必要时说明文件位置、依赖和验证方式。", true
	case "article":
		return "你是一个专业的文章撰写助手。根据主题、受众和篇幅生成结构完整的文章，包含标题、导语、正文层次和收束。", true
	case "story":
		return "你是一个专业的故事创作助手。围绕人物、冲突、场景和情绪推进叙事，保持节奏、画面感和角色动机一致。", true
	case "poem":
		return "你是一个专业的诗歌创作助手。根据意象、情绪和体裁写出有韵律、有画面感的诗句，避免空泛堆词。", true
	default:
		return "", false
	}
}
