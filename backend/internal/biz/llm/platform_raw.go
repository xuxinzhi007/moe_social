package llmbiz

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"

	"backend/pkg/llminference"
)

const maxRawBody = 1 << 20
const maxOutputTokens = 4096

// RawInput is decoded into a strict DTO; headers, metadata, tools and arbitrary options are never forwarded.
type rawInput struct {
	Model    string `json:"model"`
	Name     string `json:"name"`
	Messages []struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"messages"`
	Stream        bool     `json:"stream"`
	Temperature   *float64 `json:"temperature"`
	TopP          *float64 `json:"top_p"`
	RepeatPenalty *float64 `json:"repeat_penalty"`
	MaxTokens     *int     `json:"max_tokens"`
	Options       struct {
		Temperature   *float64 `json:"temperature"`
		TopP          *float64 `json:"top_p"`
		RepeatPenalty *float64 `json:"repeat_penalty"`
		NumPredict    *int     `json:"num_predict"`
	} `json:"options"`
}

func decodeRaw(r *http.Request) (rawInput, error) {
	var in rawInput
	if r.Body == nil {
		return in, llmError(400, "缺少请求体")
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxRawBody+1))
	if err != nil {
		return in, llmError(400, "读取请求失败")
	}
	if len(body) > maxRawBody {
		return in, llmError(413, "请求体过大")
	}
	if err := json.Unmarshal(body, &in); err != nil {
		return in, llmError(400, "无效 JSON 请求")
	}
	if in.Model == "" {
		in.Model = in.Name
	}
	return in, nil
}
func boundedTokens(v int) int {
	if v <= 0 || v > maxOutputTokens {
		return maxOutputTokens
	}
	return v
}
func (u *ManagedModels) ForwardChatRaw(w http.ResponseWriter, r *http.Request, owner uint) error {
	if r.Method != http.MethodPost {
		return llmError(405, "需要 POST")
	}
	in, err := decodeRaw(r)
	if err != nil {
		return err
	}
	if in.Model == "" {
		in.Model = u.cfg.DefaultModel
	}
	if err := u.Authorize(r.Context(), owner, in.Model); err != nil {
		return err
	}
	if len(in.Messages) == 0 || len(in.Messages) > 256 {
		return llmError(400, "需要有效的消息列表")
	}
	for _, message := range in.Messages {
		switch message.Role {
		case "system", "user", "assistant":
		default:
			return llmError(400, "不支持此消息角色")
		}
	}
	temp, topP, repeat, tokens := in.Temperature, in.TopP, in.RepeatPenalty, in.MaxTokens
	if in.Options.Temperature != nil {
		temp = in.Options.Temperature
	}
	if in.Options.TopP != nil {
		topP = in.Options.TopP
	}
	if in.Options.RepeatPenalty != nil {
		repeat = in.Options.RepeatPenalty
	}
	if in.Options.NumPredict != nil {
		tokens = in.Options.NumPredict
	}
	if temp != nil && (*temp < 0 || *temp > 2) || topP != nil && (*topP < 0 || *topP > 1) || repeat != nil && (*repeat < 0 || *repeat > 2) {
		return llmError(400, "采样参数超出范围")
	}
	maxTokens := maxOutputTokens
	if tokens != nil {
		maxTokens = boundedTokens(*tokens)
	}
	body := map[string]any{"model": in.Model, "messages": in.Messages, "stream": in.Stream}
	if string(u.cfg.APIStyle) == "ollama" {
		options := map[string]any{"num_predict": maxTokens}
		if temp != nil {
			options["temperature"] = *temp
		}
		if topP != nil {
			options["top_p"] = *topP
		}
		if repeat != nil {
			options["repeat_penalty"] = *repeat
		}
		body["options"] = options
		body["think"] = false
	} else {
		body["max_tokens"] = maxTokens
		if temp != nil {
			body["temperature"] = *temp
		}
		if topP != nil {
			body["top_p"] = *topP
		}
		if repeat != nil {
			body["repeat_penalty"] = *repeat
		}
	}
	return u.forward(w, r, body, "/api/chat", "/chat/completions")
}
func (u *ManagedModels) ForwardShowRaw(w http.ResponseWriter, r *http.Request, owner uint) error {
	if string(u.cfg.APIStyle) != "ollama" {
		return llmError(400, "当前协议不支持 show")
	}
	if r.Method != http.MethodPost {
		return llmError(405, "需要 POST")
	}
	in, err := decodeRaw(r)
	if err != nil {
		return err
	}
	if err := u.Authorize(r.Context(), owner, in.Model); err != nil {
		return err
	}
	return u.forward(w, r, map[string]any{"model": in.Model}, "/api/show", "")
}
func (u *ManagedModels) forward(w http.ResponseWriter, r *http.Request, body map[string]any, ollamaPath, openAIPath string) error {
	raw, err := json.Marshal(body)
	if err != nil {
		return llmError(400, "无效请求")
	}
	request := r.Clone(r.Context())
	request.Body = io.NopCloser(bytes.NewReader(raw))
	request.ContentLength = int64(len(raw))
	request.Header = make(http.Header)
	request.Header.Set("Content-Type", "application/json")
	if err := llminference.ForwardRaw(w, request, u.cfg, ollamaPath, openAIPath); err != nil {
		return UpstreamStatusError(err)
	}
	return nil
}
func (u *ManagedModels) ForwardModelsRaw(ctx context.Context, w http.ResponseWriter, owner uint) error {
	names, err := u.ListModels(ctx, owner)
	if err != nil {
		return err
	}
	items := make([]map[string]any, 0, len(names))
	payload := map[string]any{}
	if string(u.cfg.APIStyle) == "ollama" {
		for _, name := range names {
			items = append(items, map[string]any{"name": name, "model": name})
		}
		payload["models"] = items
	} else {
		for _, name := range names {
			items = append(items, map[string]any{"id": name, "object": "model"})
		}
		payload["object"] = "list"
		payload["data"] = items
	}
	w.Header().Set("Content-Type", "application/json")
	return json.NewEncoder(w).Encode(payload)
}
