package runtime

import (
	"strings"

	"backend/model"

	"github.com/spf13/viper"
)

// communityPostGuardrails Bot 发帖场景（与 App 酒馆聊天隔离；当前默认 llama-server 基座，无 Ollama 派生模型）。
const communityPostGuardrails = `【场景】Moe 社区「动态墙」短帖。不是酒馆角色扮演，也不是官方公告。
【语感】像好友随手发朋友圈：有画面感的一个细节 + 自然口语，可幽默/好奇/吐槽，避免排比抒情与模板腔。
【禁止】剧本旁白、小说体、*动作*、「灵魂/星辰/灯火/共鸣」等空泛堆砌、「大家好」「今日也在」类开场。`

// resolvePostModel 发帖专用模型：固定基座 GGUF，不使用酒馆派生模型名。
func resolvePostModel(deps Deps, rt model.MoeAgentRuntime) string {
	if m := strings.TrimSpace(loadBotPostModelFromViper()); m != "" {
		return m
	}
	if m := strings.TrimSpace(deps.Inference.DefaultModel); m != "" {
		return m
	}
	// 兼容旧配置：仅当显式填写且不像酒馆派生别名时才用 runtime.model_name
	if m := strings.TrimSpace(rt.ModelName); m != "" && !looksLikeDerivedAgentModel(m) {
		return m
	}
	return "qwen2"
}

func loadBotPostModelFromViper() string {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return ""
	}
	if m := strings.TrimSpace(v.GetString("moe.bot_post_model")); m != "" {
		return m
	}
	if m := strings.TrimSpace(v.GetString("llm_inference.chat_model")); m != "" {
		return m
	}
	return ""
}

// looksLikeDerivedAgentModel 遗留 Ollama「创建角色」派生模型名（llama-server 场景通常不存在）。
func looksLikeDerivedAgentModel(name string) bool {
	lower := strings.ToLower(strings.TrimSpace(name))
	if lower == "" {
		return false
	}
	// 基座名通常较短；派生名常含角色 slug
	if strings.Contains(lower, "moe_guide") || strings.Contains(lower, "character") {
		return true
	}
	if strings.Count(lower, "-") >= 2 || strings.Count(lower, "_") >= 2 {
		return len(lower) > 24
	}
	return false
}

// novelStyleScore 剧本/诗意腔得分，越高越像散文模板（≥3 建议重试）。
func novelStyleScore(content string) int {
	lower := strings.ToLower(strings.TrimSpace(content))
	strong := []string{
		"灵魂", "星辰", "灯火", "寻找共鸣", "故事对话", "深夜时分", "静静等待",
		"温暖的灵魂", "不曾熄灭", "寻找温暖",
	}
	weak := []string{"宁静", "沉浸", "光芒", "陪伴", "共鸣", "时光", "诗意"}
	score := 0
	for _, m := range strong {
		if strings.Contains(lower, m) {
			score += 2
		}
	}
	for _, m := range weak {
		if strings.Contains(lower, m) {
			score++
		}
	}
	if strings.Contains(content, "*") {
		score += 2
	}
	return score
}

const novelStyleRejectThreshold = 3

// isNovelStyleContent 是否应拒绝（过严会误杀正常中文，故用加权分）。
func isNovelStyleContent(content string) bool {
	return novelStyleScore(content) >= novelStyleRejectThreshold
}

func utf8RuneCount(s string) int {
	return len([]rune(s))
}
