package llminference

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	defaultTimeout   = 120 * time.Second
	maxResponseBytes = 8 << 20
	maxErrorBytes    = 64 << 10
)

// UpstreamError is safe to expose without leaking upstream URLs, credentials or prompts.
// Uncertain means a mutating operation may have committed and must not be blindly retried.
type UpstreamError struct {
	StatusCode int
	Message    string
	Uncertain  bool
	cause      error
}

func (e *UpstreamError) Error() string { return e.Message }

// Unwrap preserves cancellation and timeout detection without exposing the cause in Error.
func (e *UpstreamError) Unwrap() error { return e.cause }

func upstreamError(message string, status int, uncertain bool) *UpstreamError {
	return &UpstreamError{StatusCode: status, Message: message, Uncertain: uncertain}
}

func timeoutOrDefault(timeout time.Duration) time.Duration {
	if timeout <= 0 {
		return defaultTimeout
	}
	return timeout
}

// NewHTTPClient shares the default transport pool and never follows redirects.
func NewHTTPClient(timeout time.Duration) *http.Client {
	return &http.Client{Timeout: timeoutOrDefault(timeout), Transport: http.DefaultTransport,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
}

func validatedURL(raw string) (*url.URL, error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u == nil || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" || u.User != nil || u.RawQuery != "" || u.ForceQuery || u.Fragment != "" || strings.Contains(raw, "#") || u.Opaque != "" {
		return nil, upstreamError("invalid inference endpoint", 0, false)
	}
	for _, part := range strings.Split(u.Path, "/") {
		if part == "." || part == ".." || strings.Contains(part, "\\") {
			return nil, upstreamError("invalid inference endpoint", 0, false)
		}
	}
	return u, nil
}

// Endpoint preserves reverse-proxy prefixes and appends OpenAI /v1 only once.
// An empty path for the selected protocol denotes an unsupported operation.
func Endpoint(cfg Config, ollamaPath, openAIPath string) (string, error) {
	u, err := validatedURL(cfg.BaseURL)
	if err != nil {
		return "", err
	}
	p := openAIPath
	switch cfg.APIStyle {
	case APIOllama:
		p = ollamaPath
	case APIOpenAI, "":
	default:
		return "", upstreamError("unsupported inference protocol", 0, false)
	}
	if p == "" || !strings.HasPrefix(p, "/") || strings.ContainsAny(p, "?#%\\") || strings.Contains(p, "//") {
		return "", upstreamError("unsupported inference operation", 0, false)
	}
	for _, part := range strings.Split(p, "/") {
		if part == "." || part == ".." {
			return "", upstreamError("unsupported inference operation", 0, false)
		}
	}
	u.Path = strings.TrimRight(u.Path, "/")
	if cfg.APIStyle != APIOllama && !strings.HasSuffix(u.Path, "/v1") {
		u.Path += "/v1"
	}
	u.Path += p
	u.RawPath = ""
	return u.String(), nil
}

// NewRequest builds a fresh JSON request using only configured Bearer credentials.
// The target must stay under the configured origin and reverse-proxy prefix.
// Execute it with NewHTTPClient to enforce the configured timeout.
func NewRequest(ctx context.Context, cfg Config, method, target string, body io.Reader) (*http.Request, error) {
	base, err := validatedURL(cfg.BaseURL)
	if err != nil {
		return nil, err
	}
	u, err := validatedURL(target)
	if err != nil {
		return nil, err
	}
	prefix := strings.TrimRight(base.Path, "/") + "/"
	if !strings.EqualFold(base.Host, u.Host) || base.Scheme != u.Scheme || !strings.HasPrefix(u.Path, prefix) {
		return nil, upstreamError("request target outside inference endpoint", 0, false)
	}
	key := strings.TrimSpace(cfg.APIKey)
	if strings.ContainsAny(key, "\r\n") {
		return nil, upstreamError("invalid inference credentials", 0, false)
	}
	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return nil, upstreamError("invalid inference request", 0, false)
	}
	req.Header.Set("Content-Type", "application/json")
	if key != "" {
		req.Header.Set("Authorization", "Bearer "+key)
	}
	return req, nil
}

func transportError(err error, write bool) error {
	uncertain := write
	var op *net.OpError
	if errors.As(err, &op) && op.Op == "dial" {
		uncertain = false
	}
	return &UpstreamError{Message: "inference transport failed", Uncertain: uncertain, cause: err}
}

func execute(client *http.Client, req *http.Request, write bool) (*http.Response, error) {
	if err := req.Context().Err(); err != nil {
		return nil, &UpstreamError{Message: "inference request canceled", cause: err}
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, transportError(err, write)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		defer resp.Body.Close()
		// Consume only a bounded amount; never reflect upstream text (it may echo secrets).
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, maxErrorBytes))
		return nil, upstreamError("inference upstream rejected request", resp.StatusCode, write && resp.StatusCode >= 500)
	}
	return resp, nil
}

func readResponse(resp *http.Response, write bool) ([]byte, error) {
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return nil, &UpstreamError{StatusCode: resp.StatusCode, Message: "inference response interrupted", Uncertain: write, cause: err}
	}
	if len(body) > maxResponseBytes {
		return nil, upstreamError("inference response too large", resp.StatusCode, write)
	}
	return body, nil
}

func jsonRequest(ctx context.Context, cfg Config, method, ollamaPath, openAIPath string, body any) (*http.Request, error) {
	target, err := Endpoint(cfg, ollamaPath, openAIPath)
	if err != nil {
		return nil, err
	}
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return nil, upstreamError("invalid inference request body", 0, false)
		}
		reader = bytes.NewReader(raw)
	}
	return NewRequest(ctx, cfg, method, target, reader)
}

func requestJSON(ctx context.Context, cfg Config, method, ollamaPath, openAIPath string, body, result any, write bool) error {
	req, err := jsonRequest(ctx, cfg, method, ollamaPath, openAIPath, body)
	if err != nil {
		return err
	}
	resp, err := execute(NewHTTPClient(cfg.Timeout), req, write)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, err := readResponse(resp, write)
	if err != nil {
		return err
	}
	if result == nil && len(bytes.TrimSpace(raw)) == 0 {
		return nil
	}
	var envelope map[string]json.RawMessage
	if json.Unmarshal(raw, &envelope) != nil || envelope == nil {
		return upstreamError("invalid inference response", resp.StatusCode, write)
	}
	if value, ok := envelope["error"]; ok && string(value) != "null" && string(value) != `""` {
		return upstreamError("inference upstream reported error", resp.StatusCode, write)
	}
	if result != nil && json.Unmarshal(raw, result) != nil {
		return upstreamError("invalid inference response", resp.StatusCode, write)
	}
	return nil
}

// ForwardRaw proxies native bytes after the caller authorizes and normalizes the body.
// It forwards no inbound credentials, cookies, query or hop headers. After headers
// are committed, copy failures abort the HTTP response instead of returning an error
// which might cause the caller to append a second JSON response.
func ForwardRaw(w http.ResponseWriter, r *http.Request, cfg Config, ollamaPath, openAIPath string) error {
	allowedOllama := map[string]bool{"/api/chat": true, "/api/generate": true, "/api/tags": true, "/api/show": true, "/api/create": true, "/api/delete": true, "/api/embed": true, "/api/embeddings": true}
	allowedOpenAI := map[string]bool{"/chat/completions": true, "/responses": true, "/models": true, "/embeddings": true, "/completions": true}
	if (ollamaPath != "" && !allowedOllama[ollamaPath]) || (openAIPath != "" && !allowedOpenAI[openAIPath]) {
		return upstreamError("unsupported inference operation", 0, false)
	}
	target, err := Endpoint(cfg, ollamaPath, openAIPath)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(r.Context(), timeoutOrDefault(cfg.Timeout))
	defer cancel()
	req, err := NewRequest(ctx, cfg, r.Method, target, r.Body)
	if err != nil {
		return err
	}
	if accept := r.Header.Get("Accept"); accept != "" {
		req.Header.Set("Accept", accept)
	}
	resp, err := NewHTTPClient(cfg.Timeout).Do(req)
	if err != nil {
		return transportError(err, ollamaPath == "/api/create" || ollamaPath == "/api/delete")
	}
	defer resp.Body.Close()
	// Only protocol content headers are propagated, never Location or Set-Cookie.
	if contentType := resp.Header.Get("Content-Type"); contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	w.WriteHeader(resp.StatusCode)
	controller := http.NewResponseController(w)
	flush := func() {
		if err := controller.Flush(); err != nil && !errors.Is(err, http.ErrNotSupported) {
			panic(http.ErrAbortHandler)
		}
	}
	flush()
	var source io.Reader = resp.Body
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		source = io.LimitReader(resp.Body, maxErrorBytes+1)
	}
	buffer := make([]byte, 32<<10)
	var copied int
	for {
		n, readErr := source.Read(buffer)
		if n > 0 {
			copied += n
			if (resp.StatusCode < 200 || resp.StatusCode >= 300) && copied > maxErrorBytes {
				panic(http.ErrAbortHandler)
			}
			if _, err := w.Write(buffer[:n]); err != nil {
				panic(http.ErrAbortHandler)
			}
			flush()
		}
		if readErr == io.EOF {
			return nil
		}
		if readErr != nil {
			panic(http.ErrAbortHandler)
		}
	}
}
