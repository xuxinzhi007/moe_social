package llminference

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

type responsesRequest struct {
	Model        string  `json:"model"`
	Instructions string  `json:"instructions,omitempty"`
	Input        string  `json:"input"`
	Stream       bool    `json:"stream"`
	Temperature  float64 `json:"temperature,omitempty"`
	TopP         float64 `json:"top_p,omitempty"`
	MaxTokens    int     `json:"max_output_tokens,omitempty"`
}

func postResponsesChat(
	ctx context.Context,
	client *http.Client,
	cfg Config,
	model string,
	messages []Message,
	opts ChatOptions,
) (string, error) {
	body, err := json.Marshal(newResponsesRequest(model, messages, opts, false))
	if err != nil {
		return "", err
	}
	req, err := newResponsesRequestHTTP(ctx, cfg, body)
	if err != nil {
		return "", err
	}
	resp, err := execute(client, req, false)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	responseBody, err := readResponse(resp, false)
	if err != nil {
		return "", err
	}
	return parseResponsesText(responseBody)
}

func newResponsesRequest(model string, messages []Message, opts ChatOptions, stream bool) responsesRequest {
	instructions, input := responsesPrompt(messages)
	return responsesRequest{
		Model:        model,
		Instructions: instructions,
		Input:        input,
		Stream:       stream,
		Temperature:  opts.Temperature,
		TopP:         opts.TopP,
		MaxTokens:    opts.MaxTokens,
	}
}

func responsesPrompt(messages []Message) (string, string) {
	var instructions strings.Builder
	var input strings.Builder
	for _, message := range messages {
		content := strings.TrimSpace(message.Content)
		if content == "" {
			continue
		}
		if message.Role == "system" {
			if instructions.Len() > 0 {
				instructions.WriteString("\n\n")
			}
			instructions.WriteString(content)
			continue
		}
		if input.Len() > 0 {
			input.WriteByte('\n')
		}
		if message.Role == "assistant" {
			input.WriteString("伙伴：")
		} else {
			input.WriteString("用户：")
		}
		input.WriteString(content)
	}
	return instructions.String(), input.String()
}

func newResponsesRequestHTTP(ctx context.Context, cfg Config, body []byte) (*http.Request, error) {
	target, err := Endpoint(cfg, "", "/responses")
	if err != nil {
		return nil, err
	}
	return NewRequest(ctx, cfg, http.MethodPost, target, bytes.NewReader(body))
}

func parseResponsesText(raw []byte) (string, error) {
	var response struct {
		Error      json.RawMessage `json:"error"`
		Status     string          `json:"status"`
		OutputText string          `json:"output_text"`
		Output     []struct {
			Content []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			} `json:"content"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &response); err != nil {
		return "", upstreamError("invalid inference response", 200, false)
	}
	if (len(response.Error) > 0 && string(response.Error) != "null") || response.Status == "failed" || response.Status == "incomplete" {
		return "", upstreamError("inference upstream reported error", 200, false)
	}
	if text := strings.TrimSpace(response.OutputText); text != "" {
		return text, nil
	}
	var text strings.Builder
	for _, output := range response.Output {
		for _, content := range output.Content {
			if content.Type == "output_text" {
				text.WriteString(content.Text)
			}
		}
	}
	if text := strings.TrimSpace(text.String()); text != "" {
		return text, nil
	}
	return "", fmt.Errorf("responses chat empty output")
}
