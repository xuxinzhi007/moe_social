package llmbiz

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/pkg/llminference"
)

func chatRawPath(style llminference.APIStyle) string {
	_ = style
	return "/v1/chat/completions"
}

// ForwardChatRaw 将请求体原样转发到本地推理服务（流式响应）。
func ForwardChatRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("llm inference base url is empty, set llm_inference.base_url in config")
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	target := strings.TrimRight(cfg.BaseURL, "/") + chatRawPath(cfg.APIStyle)
	client := &http.Client{Timeout: 0}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost, target, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	applyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	} else {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
	}
	w.WriteHeader(resp.StatusCode)

	flusher, _ := w.(http.Flusher)
	buf := make([]byte, 16*1024)
	for {
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return nil
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return readErr
		}
	}
	return nil
}

// ForwardModelsRaw 返回 Ollama /api/tags 的原始 JSON。
func ForwardModelsRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("llm inference base url is empty, set llm_inference.base_url in config")
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = 10 * time.Second
	}

	client := &http.Client{Timeout: timeout}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, cfg.BaseURL+"/api/tags", nil)
	if err != nil {
		return err
	}
	applyInferenceForwardHeaders(req)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(raw)
	return nil
}

// ForwardShowRaw 代理 POST /api/show 到 Ollama，返回原始响应。
func ForwardShowRaw(w http.ResponseWriter, r *http.Request, cfg llminference.Config) error {
	if !cfg.Ready() {
		return fmt.Errorf("llm inference base url is empty, set llm_inference.base_url in config")
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: timeout}
	req, err := http.NewRequestWithContext(
		r.Context(), http.MethodPost,
		cfg.BaseURL+"/api/show",
		strings.NewReader(string(body)),
	)
	if err != nil {
		return err
	}
	applyInferenceForwardHeaders(req)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(resp.Body)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(raw)
	return nil
}
