package llminference

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func requireUpstreamError(t *testing.T, err error, status int, uncertain bool) {
	t.Helper()
	var got *UpstreamError
	if !errors.As(err, &got) || got.StatusCode != status || got.Uncertain != uncertain {
		t.Fatalf("error = %#v, want upstream status=%d uncertain=%v", err, status, uncertain)
	}
	for _, secret := range []string{"secret-key", "private-prompt", "http://", "https://"} {
		if strings.Contains(err.Error(), secret) {
			t.Fatalf("unsafe error: %s", err)
		}
	}
}

func TestEndpoint(t *testing.T) {
	for _, tc := range []struct {
		root  string
		style APIStyle
		want  string
	}{
		{"https://example.com", APIOpenAI, "https://example.com/v1/chat/completions"},
		{"https://example.com/proxy/v1/", APIOpenAI, "https://example.com/proxy/v1/chat/completions"},
		{"https://example.com/proxy/", APIOpenAI, "https://example.com/proxy/v1/chat/completions"},
		{"https://example.com/proxy/", APIOllama, "https://example.com/proxy/api/chat"},
	} {
		got, err := Endpoint(Config{BaseURL: tc.root, APIStyle: tc.style}, "/api/chat", "/chat/completions")
		if err != nil || got != tc.want {
			t.Fatalf("Endpoint(%s) = %s, %v", tc.root, got, err)
		}
	}
	for _, root := range []string{"", "file:///tmp/socket", "http://user:secret-key@example.com", "http://example.com?q=1", "http://example.com?", "http://example.com#frag", "http://example.com#", "http://example.com/%2e%2e/x", "http://example.com:bad"} {
		_, err := Endpoint(Config{BaseURL: root}, "", "/models")
		requireUpstreamError(t, err, 0, false)
	}
	for _, p := range []string{"", "//other/models", "/../models", "/models?q=1", "/models#x"} {
		_, err := Endpoint(Config{BaseURL: "https://example.com"}, "", p)
		requireUpstreamError(t, err, 0, false)
	}
	_, err := Endpoint(Config{BaseURL: "https://example.com", APIStyle: APIOpenAI}, "/api/create", "")
	requireUpstreamError(t, err, 0, false)
}

func TestOllamaChatOptionsAndCredentials(t *testing.T) {
	for _, stream := range []bool{false, true} {
		t.Run(map[bool]string{false: "chat", true: "stream"}[stream], func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/proxy/api/chat" || r.Header.Get("Authorization") != "Bearer secret-key" {
					t.Errorf("incorrect target/credentials")
				}
				var body map[string]any
				if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
					t.Error(err)
				}
				if body["think"] != false || body["stream"] != stream || body["model"] != "moe-user-explicit" {
					t.Errorf("body = %+v", body)
				}
				want := map[string]any{"temperature": 0.4, "top_p": 0.8, "num_predict": float64(50), "repeat_penalty": 1.1}
				if !reflect.DeepEqual(body["options"], want) {
					t.Errorf("options = %+v", body["options"])
				}
				for _, key := range []string{"temperature", "top_p", "max_tokens", "num_predict", "repeat_penalty"} {
					if _, ok := body[key]; ok {
						t.Errorf("top-level option %s", key)
					}
				}
				_, _ = io.WriteString(w, `{"message":{"content":"hello"},"done":true}`+"\n")
			}))
			defer server.Close()
			cfg := Config{BaseURL: server.URL + "/proxy", APIStyle: APIOllama, APIKey: "secret-key"}
			opts := ChatOptions{Temperature: 0.4, TopP: 0.8, MaxTokens: 50, RepeatPenalty: 1.1}
			var got string
			var err error
			if stream {
				got, err = ChatStream(context.Background(), cfg, "moe-user-explicit", nil, opts, nil)
			} else {
				got, err = Chat(context.Background(), cfg, "moe-user-explicit", nil, opts)
			}
			if err != nil || got != "hello" {
				t.Fatalf("got %q, %v", got, err)
			}
		})
	}
}

func TestModelOperations(t *testing.T) {
	var calls []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls = append(calls, r.URL.Path)
		if r.Header.Get("Authorization") != "Bearer secret-key" || r.Header.Get("Content-Type") != "application/json" {
			t.Error("missing configured headers")
		}
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Error(err)
		}
		if body["model"] != "moe-user-test" {
			t.Errorf("model = %v", body["model"])
		}
		switch r.URL.Path {
		case "/prefix/api/create":
			if r.Method != http.MethodPost || !reflect.DeepEqual(body, map[string]any{"model": "moe-user-test", "from": "qwen:latest", "system": "private-prompt", "stream": false}) {
				t.Errorf("create body = %+v", body)
			}
			_, _ = io.WriteString(w, `{"status":"success"}`)
		case "/prefix/api/show":
			_, _ = io.WriteString(w, `{"system":"sys","modelfile":"FROM qwen","template":"tpl","parameters":"temperature 0.4","details":{"family":"qwen"}}`)
		case "/prefix/api/delete":
			if r.Method != http.MethodDelete {
				t.Errorf("method = %s", r.Method)
			}
			w.WriteHeader(http.StatusOK)
		default:
			t.Errorf("unexpected request %s (must never pull)", r.URL.Path)
		}
	}))
	defer server.Close()
	cfg := Config{BaseURL: server.URL + "/prefix", APIStyle: APIOllama, APIKey: "secret-key"}
	if err := CreateModel(context.Background(), cfg, "moe-user-test", "qwen:latest", "private-prompt"); err != nil {
		t.Fatal(err)
	}
	info, err := ShowModel(context.Background(), cfg, "moe-user-test")
	if err != nil || info.System != "sys" || info.Modelfile != "FROM qwen" || info.Template != "tpl" || info.Parameters != "temperature 0.4" || info.Details["family"] != "qwen" {
		t.Fatalf("info=%+v err=%v", info, err)
	}
	if err := DeleteModel(context.Background(), cfg, "moe-user-test"); err != nil {
		t.Fatal(err)
	}
	if len(calls) != 3 {
		t.Fatalf("calls=%v", calls)
	}
}

func TestModelInfoSystemPrompt(t *testing.T) {
	for _, tc := range []struct {
		name string
		info ModelInfo
		want string
	}{
		{name: "direct", info: ModelInfo{System: " direct prompt "}, want: " direct prompt "},
		{name: "triple", info: ModelInfo{Modelfile: "FROM qwen\nSYSTEM \"\"\"triple prompt\nline two\"\"\""}, want: "triple prompt\nline two"},
		{name: "quoted", info: ModelInfo{Modelfile: "FROM qwen\nSYSTEM \"quoted prompt\""}, want: "quoted prompt"},
		{name: "empty", info: ModelInfo{Modelfile: "FROM qwen"}, want: ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := tc.info.SystemPrompt(); got != tc.want {
				t.Fatalf("SystemPrompt() = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestModelWriteFailures(t *testing.T) {
	for _, op := range []string{"create", "delete"} {
		for _, tc := range []struct {
			name, body string
			status     int
			uncertain  bool
		}{
			{"bad-json", `{"oops":`, 200, true},
			{"error", `{"error":"private-prompt secret-key http://internal"}`, 200, true},
			{"denied", `private-prompt secret-key`, 403, false},
			{"missing", `private-prompt`, 404, false},
			{"server", `private-prompt`, 503, true},
		} {
			t.Run(op+"/"+tc.name, func(t *testing.T) {
				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(tc.status)
					_, _ = io.WriteString(w, tc.body)
				}))
				defer server.Close()
				cfg := Config{BaseURL: server.URL, APIStyle: APIOllama}
				var err error
				if op == "create" {
					err = CreateModel(context.Background(), cfg, "moe-user-x", "base", "private-prompt")
				} else {
					err = DeleteModel(context.Background(), cfg, "moe-user-x")
				}
				requireUpstreamError(t, err, tc.status, tc.uncertain)
			})
		}
	}
	for _, body := range []string{`{}`, `{"status":"pulling"}`, `{"status":"success","error":"private-prompt"}`, `{"status":"success"} trailing`, `null`, ""} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, body) }))
		err := CreateModel(context.Background(), Config{BaseURL: server.URL, APIStyle: APIOllama}, "moe-user-x", "base", "private-prompt")
		server.Close()
		requireUpstreamError(t, err, 200, true)
	}
}

func TestValidationBeforeWrite(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls.Add(1) }))
	defer server.Close()
	cfg := Config{BaseURL: server.URL, APIStyle: APIOllama}
	for _, name := range []string{"", " ", "../base", "bad\nname", "bad?name", "/base"} {
		requireUpstreamError(t, CreateModel(context.Background(), cfg, name, "base", "prompt"), 0, false)
		requireUpstreamError(t, CreateModel(context.Background(), cfg, "valid", name, "prompt"), 0, false)
		requireUpstreamError(t, DeleteModel(context.Background(), cfg, name), 0, false)
	}
	cfg.APIStyle = APIOpenAI
	requireUpstreamError(t, CreateModel(context.Background(), cfg, "valid", "base", "prompt"), 0, false)
	if calls.Load() != 0 {
		t.Fatal("invalid operation sent upstream")
	}
}

func TestListModelsAndManagedSelection(t *testing.T) {
	for _, style := range []APIStyle{APIOllama, APIOpenAI} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Authorization") != "Bearer secret-key" {
				t.Error("missing API key")
			}
			if style == APIOllama {
				if r.URL.Path != "/proxy/api/tags" {
					t.Errorf("path = %s", r.URL.Path)
				}
				_, _ = io.WriteString(w, `{"models":[{"name":"moe-user-qwen"},{"name":"public-qwen"},{"name":"public-qwen"}]}`)
			} else {
				if r.URL.Path != "/proxy/v1/models" {
					t.Errorf("path = %s", r.URL.Path)
				}
				_, _ = io.WriteString(w, `{"data":[{"id":"moe-user-qwen"},{"id":"public-qwen"}]}`)
			}
		}))
		cfg := Config{BaseURL: server.URL + "/proxy", APIStyle: style, APIKey: "secret-key"}
		for _, list := range []func(context.Context, Config) ([]string, error){ListModels, ListModelIDs, ListModelNames} {
			got, err := list(context.Background(), cfg)
			if err != nil || !reflect.DeepEqual(got, []string{"moe-user-qwen", "public-qwen"}) {
				t.Fatalf("models=%v err=%v", got, err)
			}
		}
		for _, pref := range []string{"", "qwen", "missing"} {
			if got := ResolveModelName(context.Background(), cfg, pref); got != "public-qwen" {
				t.Fatalf("auto picked %s", got)
			}
		}
		if got := ResolveModelName(context.Background(), cfg, "moe-user-qwen"); got != "moe-user-qwen" {
			t.Fatalf("explicit model blocked: %s", got)
		}
		server.Close()
	}
	if got := PickModel("", []string{"moe-user-only"}); got.ModelID != "" {
		t.Fatalf("private fallback: %+v", got)
	}
	if got := PickModel("qwen", []string{"moe-user-qwen"}); got.ModelID != "qwen" {
		t.Fatalf("private fuzzy: %+v", got)
	}
}

func TestOpenAIChatRegression(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/proxy/v1/chat/completions" || r.Header.Get("Authorization") != "Bearer secret-key" {
			t.Error("incorrect OpenAI target/headers")
		}
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Error(err)
		}
		if body["temperature"] != 0.5 || body["max_tokens"] != float64(20) || body["options"] != nil {
			t.Errorf("OpenAI body=%v", body)
		}
		if body["stream"] == true {
			_, _ = io.WriteString(w, "data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\ndata: [DONE]\n\n")
		} else {
			_, _ = io.WriteString(w, `{"choices":[{"message":{"content":"hello"}}]}`)
		}
	}))
	defer server.Close()
	cfg := Config{BaseURL: server.URL + "/proxy/v1/", APIStyle: APIOpenAI, APIKey: "secret-key"}
	opts := ChatOptions{Temperature: 0.5, MaxTokens: 20}
	got, err := Chat(context.Background(), cfg, "qwen", nil, opts)
	if err != nil || got != "hello" {
		t.Fatalf("chat=%q %v", got, err)
	}
	got, err = ChatStream(context.Background(), cfg, "qwen", nil, opts, nil)
	if err != nil || got != "hello" {
		t.Fatalf("stream=%q %v", got, err)
	}
}

func TestStreamsRejectMalformedErrorsAndTruncation(t *testing.T) {
	for _, tc := range []struct{ name, protocol, body string }{
		{"ollama-bad", "ollama", "not-json\n"},
		{"ollama-error", "ollama", `{"error":"private-prompt secret-key"}` + "\n"},
		{"ollama-truncated", "ollama", `{"message":{"content":"partial"},"done":false}` + "\n"},
		{"openai-bad", "openai", "data: not-json\n\n"},
		{"openai-error", "openai", "data: {\"error\":{\"message\":\"private-prompt\"}}\n\n"},
		{"openai-truncated", "openai", "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n"},
		{"responses-bad", "responses", "data: {bad}\n\n"},
		{"responses-error", "responses", "data: {\"type\":\"response.failed\"}\n\n"},
		{"responses-incomplete", "responses", "data: {\"type\":\"response.incomplete\"}\n\n"},
		{"responses-truncated", "responses", "data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}\n\n"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, tc.body) }))
			defer server.Close()
			cfg := Config{BaseURL: server.URL, APIStyle: APIOpenAI}
			model := "qwen"
			if tc.protocol == "ollama" {
				cfg.APIStyle = APIOllama
			}
			if tc.protocol == "responses" {
				model = "gpt-test"
			}
			got, err := ChatStream(context.Background(), cfg, model, nil, ChatOptions{}, nil)
			requireUpstreamError(t, err, 200, false)
			if strings.Contains(tc.name, "truncated") && got != "partial" {
				t.Fatalf("partial output lost: %q", got)
			}
		})
	}
	stop := errors.New("stop")
	_, err := readChatStream(strings.NewReader(`{"message":{"content":"a"},"done":true}`+"\n"), "ollama", func(string) error { return stop })
	if !errors.Is(err, stop) {
		t.Fatalf("callback error = %v", err)
	}
}

func TestRequestTimeoutCancellationAndRedirects(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = io.Copy(io.Discard, r.Body); <-r.Context().Done() }))
	cfg := Config{BaseURL: server.URL, APIStyle: APIOllama, Timeout: 30 * time.Millisecond}
	err := CreateModel(context.Background(), cfg, "new", "base", "private-prompt")
	requireUpstreamError(t, err, 0, true)
	var timeout interface{ Timeout() bool }
	if !errors.As(err, &timeout) || !timeout.Timeout() {
		t.Fatalf("timeout identity lost: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err = DeleteModel(ctx, cfg, "new")
	requireUpstreamError(t, err, 0, false)
	if !errors.Is(err, context.Canceled) {
		t.Fatal("cancellation identity lost")
	}
	server.Close()
	// The closed httptest listener is a certain dial failure, not an ambiguous write.
	err = DeleteModel(context.Background(), cfg, "new")
	requireUpstreamError(t, err, 0, false)
	var redirected atomic.Int32
	sink := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { redirected.Add(1) }))
	defer sink.Close()
	redirect := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, sink.URL, http.StatusTemporaryRedirect)
	}))
	defer redirect.Close()
	cfg.BaseURL, cfg.APIKey = redirect.URL, "secret-key"
	requireUpstreamError(t, CreateModel(context.Background(), cfg, "new", "base", "prompt"), 307, false)
	if redirected.Load() != 0 {
		t.Fatal("redirect followed")
	}
	if NewHTTPClient(0).Timeout != defaultTimeout || NewHTTPClient(time.Second).Transport != http.DefaultTransport {
		t.Fatal("HTTP defaults not shared/bounded")
	}
}

func TestForwardRawCredentialsAndNativeBytes(t *testing.T) {
	for _, key := range []string{"", "secret-key"} {
		upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/prefix/api/chat" || r.URL.RawQuery != "" {
				t.Error("untrusted target/query forwarded")
			}
			wantAuth := ""
			if key != "" {
				wantAuth = "Bearer " + key
			}
			if r.Header.Get("Authorization") != wantAuth {
				t.Error("inbound JWT forwarded or config credential missing")
			}
			for _, h := range []string{"Cookie", "X-Forwarded-For", "X-Admin", "Proxy-Authorization", "Connection", "X-Hop"} {
				if r.Header.Get(h) != "" {
					t.Errorf("untrusted header %s forwarded", h)
				}
			}
			if r.Header.Get("Accept") != "application/x-ndjson" || r.Header.Get("Content-Type") != "application/json" {
				t.Error("protocol headers missing")
			}
			body, _ := io.ReadAll(r.Body)
			if string(body) != `{"model":"authorized"}` {
				t.Errorf("body altered: %q", body)
			}
			w.Header().Set("Content-Type", "application/x-ndjson")
			w.Header().Set("Set-Cookie", "secret=value")
			w.WriteHeader(202)
			_, _ = io.WriteString(w, "{\"error\":\"native\"}\nmalformed-json\n")
		}))
		cfg := Config{BaseURL: upstream.URL + "/prefix", APIStyle: APIOllama, APIKey: key}
		r := httptest.NewRequest(http.MethodPost, "http://frontend/chat?token=jwt", strings.NewReader(`{"model":"authorized"}`))
		r.Header.Set("Authorization", "Bearer inbound.jwt")
		r.Header.Set("Cookie", "session=jwt")
		r.Header.Set("X-Forwarded-For", "attacker")
		r.Header.Set("Proxy-Authorization", "proxy-token")
		r.Header.Set("Connection", "X-Hop")
		r.Header.Set("X-Hop", "hidden")
		r.Header.Set("X-Admin", "true")
		r.Header.Set("Accept", "application/x-ndjson")
		w := httptest.NewRecorder()
		err := ForwardRaw(w, r, cfg, "/api/chat", "/chat/completions")
		upstream.Close()
		if err != nil || w.Code != 202 || w.Body.String() != "{\"error\":\"native\"}\nmalformed-json\n" || !w.Flushed {
			t.Fatalf("raw response: %d %q %v", w.Code, w.Body.String(), err)
		}
		if w.Header().Get("Set-Cookie") != "" {
			t.Fatal("unsafe response headers forwarded")
		}
	}
}

func TestForwardRawTimeoutAndAbortAfterCommit(t *testing.T) {
	for _, started := range []bool{false, true} {
		upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			_, _ = io.Copy(io.Discard, r.Body)
			if started {
				_, _ = io.WriteString(w, "partial\n")
				w.(http.Flusher).Flush()
			}
			<-r.Context().Done()
		}))
		cfg := Config{BaseURL: upstream.URL, APIStyle: APIOllama, Timeout: 30 * time.Millisecond}
		w := httptest.NewRecorder()
		var gotErr error
		var recovered any
		func() {
			defer func() { recovered = recover() }()
			gotErr = ForwardRaw(w, httptest.NewRequest(http.MethodPost, "http://frontend", strings.NewReader(`{}`)), cfg, "/api/chat", "")
		}()
		upstream.Close()
		if started {
			if recovered != http.ErrAbortHandler || gotErr != nil || w.Body.String() != "partial\n" {
				t.Fatalf("response must abort, not double encode: panic=%v err=%v body=%q", recovered, gotErr, w.Body.String())
			}
		} else {
			requireUpstreamError(t, gotErr, 0, false)
			if recovered != nil || w.Body.Len() != 0 {
				t.Fatalf("unexpected commit: %v", recovered)
			}
		}
	}
}

func TestForwardRawFixedEndpointsAndRedirect(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Location", "http://must-not-connect.invalid")
		w.WriteHeader(http.StatusTemporaryRedirect)
		_, _ = io.WriteString(w, "redirect")
	}))
	defer upstream.Close()
	cfg := Config{BaseURL: upstream.URL, APIStyle: APIOpenAI, APIKey: "secret-key"}
	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodPost, "http://frontend", strings.NewReader(`{}`))
	if err := ForwardRaw(w, r, cfg, "", "/responses"); err != nil || w.Code != 307 || w.Body.String() != "redirect" {
		t.Fatalf("redirect not passed safely: %v", err)
	}
	if w.Header().Get("Location") != "" {
		t.Fatal("redirect location exposed")
	}
	err := ForwardRaw(httptest.NewRecorder(), r, cfg, "", "/admin/keys")
	requireUpstreamError(t, err, 0, false)
	_, err = NewRequest(context.Background(), cfg, http.MethodPost, "http://other.invalid/v1/chat/completions", nil)
	requireUpstreamError(t, err, 0, false)
	cfg.BaseURL += "/prefix"
	_, err = NewRequest(context.Background(), cfg, http.MethodPost, upstream.URL+"/outside", nil)
	requireUpstreamError(t, err, 0, false)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err = ForwardRaw(httptest.NewRecorder(), r.WithContext(ctx), cfg, "", "/responses")
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("cancel=%v", err)
	}
}

func TestForwardRawFlushBeforeCompletion(t *testing.T) {
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		_, _ = io.WriteString(w, "first")
		w.(http.Flusher).Flush()
		select {
		case <-release:
		case <-r.Context().Done():
			return
		}
		_, _ = io.WriteString(w, "last")
	}))
	defer upstream.Close()
	cfg := Config{BaseURL: upstream.URL, APIStyle: APIOllama, Timeout: time.Second}
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := ForwardRaw(w, r, cfg, "/api/chat", ""); err != nil {
			t.Errorf("forward: %v", err)
		}
	}))
	defer proxy.Close()
	resp, err := NewHTTPClient(time.Second).Post(proxy.URL, "application/json", strings.NewReader(`{}`))
	if err != nil {
		close(release)
		t.Fatal(err)
	}
	defer resp.Body.Close()
	first := make([]byte, 5)
	_, err = io.ReadFull(resp.Body, first)
	close(release)
	if err != nil || string(first) != "first" {
		t.Fatalf("not flushed: %q %v", first, err)
	}
	last, err := io.ReadAll(resp.Body)
	if err != nil || string(last) != "last" {
		t.Fatalf("not completed: %q %v", last, err)
	}
}

func TestOllamaReadFailures(t *testing.T) {
	for _, body := range []string{`{"error":"private-prompt"}`, `not-json`, `null`} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, body) }))
		cfg := Config{BaseURL: server.URL, APIStyle: APIOllama}
		_, err := ShowModel(context.Background(), cfg, "model")
		requireUpstreamError(t, err, 200, false)
		_, err = Chat(context.Background(), cfg, "model", nil, ChatOptions{})
		requireUpstreamError(t, err, 200, false)
		_, err = ListModels(context.Background(), cfg)
		requireUpstreamError(t, err, 200, false)
		server.Close()
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"message":{"content":"partial"}}`)
	}))
	defer server.Close()
	_, err := Chat(context.Background(), Config{BaseURL: server.URL, APIStyle: APIOllama}, "model", nil, ChatOptions{})
	requireUpstreamError(t, err, 200, false)
}

func TestBoundedResponses(t *testing.T) {
	for _, status := range []int{200, 500} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(status)
			_, _ = io.WriteString(w, strings.Repeat("x", maxResponseBytes+10))
		}))
		err := CreateModel(context.Background(), Config{BaseURL: server.URL, APIStyle: APIOllama}, "new", "base", "prompt")
		server.Close()
		requireUpstreamError(t, err, status, true)
	}
}
