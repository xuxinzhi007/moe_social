package common

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/spf13/viper"
)

// InferenceSlotInfo 从 llama-server /props 或配置读取的上下文信息。
type InferenceSlotInfo struct {
	ContextLimit int    `json:"context_limit"`
	Source       string `json:"source"` // props|config|default
}

// EstimateTokens 粗略 token 估算（中英混合约 4 字符/token）。
func EstimateTokens(text string) int {
	n := len([]rune(strings.TrimSpace(text)))
	if n <= 0 {
		return 0
	}
	t := n / 4
	if t < 1 {
		return 1
	}
	return t
}

// ContextLimitFromViper 配置兜底（llm_inference.context_tokens）。
func ContextLimitFromViper() int {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return 8192
	}
	if n := v.GetInt("llm_inference.context_tokens"); n > 0 {
		return n
	}
	return 8192
}

// FetchInferenceSlotInfo 尝试 GET {base}/props 读取 default_generation_settings.n_ctx。
func FetchInferenceSlotInfo(ctx context.Context, client *http.Client, baseURL string) InferenceSlotInfo {
	fallback := InferenceSlotInfo{
		ContextLimit: ContextLimitFromViper(),
		Source:       "config",
	}
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if base == "" {
		fallback.Source = "default"
		if fallback.ContextLimit <= 0 {
			fallback.ContextLimit = 8192
		}
		return fallback
	}
	url := base + "/props"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fallback
	}
	ApplyInferenceForwardHeaders(req)
	resp, err := client.Do(req)
	if err != nil {
		return fallback
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fallback
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fallback
	}
	var parsed struct {
		DefaultGenerationSettings struct {
			NCtx int `json:"n_ctx"`
		} `json:"default_generation_settings"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return fallback
	}
	if parsed.DefaultGenerationSettings.NCtx > 0 {
		return InferenceSlotInfo{
			ContextLimit: parsed.DefaultGenerationSettings.NCtx,
			Source:       "props",
		}
	}
	return fallback
}

// ContextUsedPercent 已用 token 占上下文比例（0~1）。
func ContextUsedPercent(used, limit int) float64 {
	if limit <= 0 || used <= 0 {
		return 0
	}
	p := float64(used) / float64(limit)
	if p > 1 {
		return 1
	}
	return p
}

// FetchInferenceSlotInfoWithTimeout 带短超时的 props 查询。
func FetchInferenceSlotInfoWithTimeout(baseURL string, timeoutSec int) InferenceSlotInfo {
	if timeoutSec <= 0 {
		timeoutSec = 5
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec)*time.Second)
	defer cancel()
	client := &http.Client{Timeout: time.Duration(timeoutSec) * time.Second}
	return FetchInferenceSlotInfo(ctx, client, baseURL)
}

// PropsUnavailableHint 当 /props 不可用时给运维的提示。
func PropsUnavailableHint(baseURL string, err error) string {
	if err == nil {
		return ""
	}
	return fmt.Sprintf("无法读取 %s/props（%v）；可在 config.yaml 设置 llm_inference.context_tokens", strings.TrimRight(baseURL, "/"), err)
}
