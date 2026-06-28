package moeconfig

import (
	"os"
	"strings"

	"backend/pkg/llminference"

	"github.com/spf13/viper"
)

// InferenceFromViper 读取 config.yaml 中的 llm_inference（兼容 ollama 键）。
func InferenceFromViper() llminference.Config {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()
	base := v.GetString("llm_inference.base_url")
	if base == "" {
		base = v.GetString("ollama.base_url")
	}
	style := v.GetString("llm_inference.api_style")
	if style == "" {
		style = v.GetString("ollama.api_style")
	}
	ts := v.GetInt("llm_inference.timeout_seconds")
	if ts <= 0 {
		ts = v.GetInt("ollama.timeout_seconds")
	}
	model := v.GetString("llm_inference.memory_model")
	if model == "" {
		model = v.GetString("ollama.memory_model")
	}
	apiKey := strings.TrimSpace(os.Getenv("MOE_LLM_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(v.GetString("llm_inference.api_key"))
	}
	if apiKey == "" {
		apiKey = strings.TrimSpace(v.GetString("ollama.api_key"))
	}
	return llminference.ConfigFrom(base, style, ts, model, apiKey)
}
