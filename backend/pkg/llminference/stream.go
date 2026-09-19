package llminference

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

// StreamHandler receives text deltas; returning an error stops the stream.
type StreamHandler func(chunk string) error

// ChatStream returns assembled text, retaining partial text on stream failure.
func ChatStream(ctx context.Context, cfg Config, model string, messages []Message, opts ChatOptions, onChunk StreamHandler) (string, error) {
	model = firstNonEmpty(model, cfg.DefaultModel, "qwen2")
	var body any
	var nativePath, openAIPath string
	protocol := "openai"
	switch {
	case cfg.APIStyle == APIOllama:
		body = newOllamaChatRequest(model, messages, opts, true)
		nativePath, protocol = "/api/chat", "ollama"
	case usesResponsesAPI(model):
		body = newResponsesRequest(model, messages, opts, true)
		openAIPath, protocol = "/responses", "responses"
	default:
		body = newOpenAIChatRequest(model, messages, opts, true)
		openAIPath = "/chat/completions"
	}
	req, err := jsonRequest(ctx, cfg, http.MethodPost, nativePath, openAIPath, body)
	if err != nil {
		return "", err
	}
	if protocol != "ollama" {
		req.Header.Set("Accept", "text/event-stream")
	}
	resp, err := execute(NewHTTPClient(cfg.Timeout), req, false)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	return readChatStream(resp.Body, protocol, onChunk)
}

func readResponsesStream(r io.Reader, onChunk StreamHandler) (string, error) {
	return readChatStream(r, "responses", onChunk)
}

func readOpenAIStream(r io.Reader, onChunk StreamHandler) (string, error) {
	return readChatStream(r, "openai", onChunk)
}

type streamEvent struct {
	Error    json.RawMessage `json:"error"`
	Type     string          `json:"type"`
	Delta    string          `json:"delta"`
	Message  Message         `json:"message"`
	Done     bool            `json:"done"`
	Response struct {
		Status string          `json:"status"`
		Error  json.RawMessage `json:"error"`
	} `json:"response"`
	Choices []struct {
		Delta Message `json:"delta"`
	} `json:"choices"`
}

func readChatStream(r io.Reader, protocol string, onChunk StreamHandler) (string, error) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64<<10), 1<<20)
	var full strings.Builder
	var total int
	done := false
	consume := func(payload string) error {
		if payload == "[DONE]" && protocol != "ollama" {
			done = true
			return nil
		}
		var event streamEvent
		if json.Unmarshal([]byte(payload), &event) != nil || strings.TrimSpace(payload) == "null" {
			return upstreamError("invalid inference stream event", 200, false)
		}
		hasError := func(raw json.RawMessage) bool { return len(raw) != 0 && string(raw) != "null" && string(raw) != `""` }
		if hasError(event.Error) || hasError(event.Response.Error) || event.Type == "error" || event.Type == "response.failed" || event.Type == "response.incomplete" || event.Response.Status == "failed" || event.Response.Status == "incomplete" {
			return upstreamError("inference stream reported error", 200, false)
		}
		var chunk string
		switch protocol {
		case "ollama":
			chunk, done = event.Message.Content, event.Done
		case "responses":
			if event.Type == "response.output_text.delta" {
				chunk = event.Delta
			}
			done = event.Type == "response.completed"
		default:
			if len(event.Choices) > 0 {
				chunk = event.Choices[0].Delta.Content
			}
		}
		if chunk != "" {
			full.WriteString(chunk)
			if onChunk != nil {
				return onChunk(chunk)
			}
		}
		return nil
	}
	// SSE data fields in one event may span multiple lines. NDJSON uses one
	// event per line. Both protocols require a terminal event, never bare EOF.
	var data []string
	for scanner.Scan() {
		line := scanner.Text()
		total += len(line) + 1
		if total > maxResponseBytes {
			return full.String(), upstreamError("inference stream too large", 200, false)
		}
		if protocol == "ollama" {
			if strings.TrimSpace(line) == "" {
				continue
			}
			if err := consume(line); err != nil {
				return full.String(), err
			}
		} else {
			if line != "" {
				if strings.HasPrefix(line, "data:") {
					data = append(data, strings.TrimPrefix(strings.TrimPrefix(line, "data:"), " "))
				}
				continue
			}
			if len(data) == 0 {
				continue
			}
			if err := consume(strings.Join(data, "\n")); err != nil {
				return full.String(), err
			}
			data = nil
		}
		if done {
			break
		}
	}
	if err := scanner.Err(); err != nil {
		return full.String(), transportError(err, false)
	}
	if !done && len(data) > 0 {
		if err := consume(strings.Join(data, "\n")); err != nil {
			return full.String(), err
		}
	}
	if !done {
		return full.String(), upstreamError("incomplete inference stream", 200, false)
	}
	if strings.TrimSpace(full.String()) == "" {
		return "", upstreamError("inference stream empty", 200, false)
	}
	return strings.TrimSpace(full.String()), nil
}
