package platformhttp

import (
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	llmapp "backend/internal/service/llm"
	"backend/pkg/llminference"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const rawTestModel = "qwen2.5:latest"

type rawUpstream struct {
	path    string
	body    string
	auth    string
	cookie  string
	payload string
}

// 三个透传端点必须是 Kratos 原生路由，且按 api_style 打正确的上游路径。
// 请求体不是盲透传：由受限 DTO 重建，所以采样参数落点、凭据隔离都要断言。
func TestLLMRawRoutesHitProtocolPaths(t *testing.T) {
	cases := []struct {
		name       string
		style      string
		method     string
		route      string
		body       string
		wantPath   string
		wantStatus int
		check      func(t *testing.T, got rawUpstream, respBody []byte)
	}{
		{
			name: "ollama/chat", style: "ollama", method: http.MethodPost, route: "/api/llm/chat/raw",
			body:       `{"model":"` + rawTestModel + `","messages":[{"role":"user","content":"你好"}],"temperature":0.3,"max_tokens":64,"tools":[{"evil":true}],"api_key":"leak"}`,
			wantPath:   "/api/chat",
			wantStatus: http.StatusTeapot,
			check: func(t *testing.T, got rawUpstream, respBody []byte) {
				var decoded map[string]any
				if err := json.Unmarshal([]byte(got.body), &decoded); err != nil {
					t.Fatalf("上游请求体不是合法 JSON: %v (%q)", err, got.body)
				}
				options, ok := decoded["options"].(map[string]any)
				if !ok {
					t.Fatalf("Ollama 采样参数必须放进 options: %s", got.body)
				}
				if options["temperature"] != 0.3 {
					t.Errorf("temperature 未进 options: %s", got.body)
				}
				if options["num_predict"] != float64(64) {
					t.Errorf("max_tokens 必须映射成 num_predict: %s", got.body)
				}
				if decoded["think"] != false {
					t.Errorf("Ollama chat 必须显式 think=false: %s", got.body)
				}
				if _, exists := decoded["tools"]; exists {
					t.Errorf("raw 不得转发 tools: %s", got.body)
				}
				if _, exists := decoded["temperature"]; exists {
					t.Errorf("Ollama 顶层不得出现 temperature: %s", got.body)
				}
				if !strings.Contains(string(respBody), "from-fake-inference") {
					t.Errorf("上游响应体未回到客户端: %s", respBody)
				}
			},
		},
		{
			name: "openai/chat", style: "openai", method: http.MethodPost, route: "/api/llm/chat/raw",
			body:       `{"model":"` + rawTestModel + `","messages":[{"role":"user","content":"你好"}],"temperature":0.3,"max_tokens":64}`,
			wantPath:   "/v1/chat/completions",
			wantStatus: http.StatusTeapot,
			check: func(t *testing.T, got rawUpstream, respBody []byte) {
				var decoded map[string]any
				if err := json.Unmarshal([]byte(got.body), &decoded); err != nil {
					t.Fatalf("上游请求体不是合法 JSON: %v (%q)", err, got.body)
				}
				if decoded["temperature"] != 0.3 || decoded["max_tokens"] != float64(64) {
					t.Errorf("OpenAI 采样参数应留在顶层: %s", got.body)
				}
				if _, exists := decoded["options"]; exists {
					t.Errorf("OpenAI 请求不得带 Ollama options: %s", got.body)
				}
			},
		},
		{
			name: "ollama/show", style: "ollama", method: http.MethodPost, route: "/api/llm/show/raw",
			body: `{"model":"` + rawTestModel + `"}`, wantPath: "/api/show", wantStatus: http.StatusTeapot,
			check: func(t *testing.T, got rawUpstream, respBody []byte) {
				if got.body != `{"model":"`+rawTestModel+`"}` {
					t.Errorf("show 请求体应只含 model: %s", got.body)
				}
			},
		},
		{
			name: "ollama/models", style: "ollama", method: http.MethodGet, route: "/api/llm/models/raw",
			wantPath: "/api/tags", wantStatus: http.StatusOK,
			check: func(t *testing.T, got rawUpstream, respBody []byte) {
				if !strings.Contains(string(respBody), rawTestModel) {
					t.Errorf("目录应包含允许的基座: %s", respBody)
				}
				if strings.Contains(string(respBody), "moe-user-") {
					t.Errorf("匿名目录不得泄露受管模型: %s", respBody)
				}
			},
		},
		{
			name: "openai/models", style: "openai", method: http.MethodGet, route: "/api/llm/models/raw",
			wantPath: "/v1/models", wantStatus: http.StatusOK,
			check: func(t *testing.T, got rawUpstream, respBody []byte) {
				var decoded struct {
					Object string `json:"object"`
					Data   []struct {
						ID string `json:"id"`
					} `json:"data"`
				}
				if err := json.Unmarshal(respBody, &decoded); err != nil {
					t.Fatalf("目录响应不是合法 JSON: %v (%s)", err, respBody)
				}
				if decoded.Object != "list" || len(decoded.Data) != 1 || decoded.Data[0].ID != rawTestModel {
					t.Errorf("OpenAI 目录结构不符: %s", respBody)
				}
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var got rawUpstream
			fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				raw, _ := io.ReadAll(r.Body)
				got = rawUpstream{path: r.URL.Path, body: string(raw), auth: r.Header.Get("Authorization"), cookie: r.Header.Get("Cookie"), payload: modelsPayload(tc.style)}
				w.Header().Set("Content-Type", "application/json")
				if strings.HasSuffix(r.URL.Path, "/models") || strings.HasSuffix(r.URL.Path, "/api/tags") {
					w.WriteHeader(http.StatusOK)
					_, _ = io.WriteString(w, got.payload)
					return
				}
				w.WriteHeader(http.StatusTeapot)
				_, _ = io.WriteString(w, `{"marker":"from-fake-inference"}`)
			}))
			defer fake.Close()

			cfg := llminference.ConfigFrom(fake.URL, tc.style, 30, rawTestModel, "configured-secret")
			base := startRawServer(t, Deps{LLMApp: llmapp.New(nil, llmapp.Deps{Inference: cfg})})

			var bodyReader io.Reader
			if tc.body != "" {
				bodyReader = strings.NewReader(tc.body)
			}
			req, err := http.NewRequest(tc.method, base+tc.route, bodyReader)
			if err != nil {
				t.Fatalf("构造请求失败: %v", err)
			}
			// 入站凭据绝不能被转发到推理端；上游只该看到服务端配置的密钥。
			req.Header.Set("Authorization", "Bearer inbound-user-jwt")
			req.Header.Set("Cookie", "session=steal-me")
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatalf("%s %s 请求失败（handler panic 会表现成这样）: %v", tc.method, tc.route, err)
			}
			defer resp.Body.Close()
			respBody, _ := io.ReadAll(resp.Body)

			if resp.StatusCode == http.StatusNotFound {
				t.Fatalf("%s 未注册成路由，拿到 404: %s", tc.route, respBody)
			}
			if resp.StatusCode != tc.wantStatus {
				t.Errorf("状态码不符: 期望 %d，实际 %d，body=%s", tc.wantStatus, resp.StatusCode, respBody)
			}
			if got.path != tc.wantPath {
				t.Errorf("打到了错误的推理路径: 期望 %s，实际 %s", tc.wantPath, got.path)
			}
			if strings.Contains(got.auth, "inbound-user-jwt") {
				t.Errorf("入站 Authorization 泄露到推理端: %q", got.auth)
			}
			if got.cookie != "" {
				t.Errorf("入站 Cookie 泄露到推理端: %q", got.cookie)
			}
			if got.auth != "Bearer configured-secret" {
				t.Errorf("上游应只带配置凭据: %q", got.auth)
			}
			tc.check(t, got, respBody)
		})
	}
}

// show 是 Ollama 专有操作：OpenAI 模式必须明确拒绝，不能退化成 POST /v1/models/。
func TestLLMRawShowRejectedOnOpenAIStyle(t *testing.T) {
	fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("OpenAI 模式下 show 不该访问上游，实际打到 %s", r.URL.Path)
		w.WriteHeader(http.StatusTeapot)
	}))
	defer fake.Close()

	cfg := llminference.ConfigFrom(fake.URL, "openai", 30, rawTestModel, "")
	base := startRawServer(t, Deps{LLMApp: llmapp.New(nil, llmapp.Deps{Inference: cfg})})

	resp, err := http.Post(base+"/api/llm/show/raw", "application/json", strings.NewReader(`{"model":"`+rawTestModel+`"}`))
	if err != nil {
		t.Fatalf("请求失败: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("期望 400，实际 %d: %s", resp.StatusCode, body)
	}
}

// 匿名不能借用他人受管模型名；猜名字必须被拒。
func TestLLMRawChatRejectsForeignManagedModel(t *testing.T) {
	fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("未授权模型不该访问上游，实际打到 %s", r.URL.Path)
		w.WriteHeader(http.StatusTeapot)
	}))
	defer fake.Close()

	cfg := llminference.ConfigFrom(fake.URL, "ollama", 30, rawTestModel, "")
	base := startRawServer(t, Deps{LLMApp: llmapp.New(nil, llmapp.Deps{Inference: cfg})})

	resp, err := http.Post(base+"/api/llm/chat/raw", "application/json",
		strings.NewReader(`{"model":"moe-user-deadbeef:latest","messages":[{"role":"user","content":"hi"}]}`))
	if err != nil {
		t.Fatalf("请求失败: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("期望 403，实际 %d: %s", resp.StatusCode, body)
	}
}

// 依赖缺失时必须 fail closed（503），不能退回无权限校验的分支，且服务要还活着。
func TestLLMRawRoutesWithoutAppFailClosed(t *testing.T) {
	base := startRawServer(t, Deps{})

	for _, route := range []string{"/api/llm/chat/raw", "/api/llm/models/raw", "/api/llm/show/raw"} {
		var resp *http.Response
		var err error
		if route == "/api/llm/models/raw" {
			resp, err = http.Get(base + route)
		} else {
			resp, err = http.Post(base+route, "application/json", strings.NewReader(`{"model":"`+rawTestModel+`"}`))
		}
		if err != nil {
			t.Fatalf("%s 请求失败: %v", route, err)
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode == http.StatusNotFound {
			t.Fatalf("%s 路由未注册，拿到 404: %s", route, body)
		}
		if resp.StatusCode != http.StatusServiceUnavailable {
			t.Errorf("%s 期望 503 fail closed，实际 %d: %s", route, resp.StatusCode, body)
		}
		if !strings.Contains(string(body), "LLM_UNAVAILABLE") {
			t.Errorf("%s 失败必须带明确 reason: %s", route, body)
		}
	}

	probe, err := http.Get(base + "/api/llm/models/raw")
	if err != nil {
		t.Fatalf("第二次请求失败，服务已被打死: %v", err)
	}
	probe.Body.Close()
}

func modelsPayload(style string) string {
	if style == "ollama" {
		return `{"models":[{"name":"` + rawTestModel + `"},{"name":"moe-user-secret:latest"}]}`
	}
	return `{"object":"list","data":[{"id":"` + rawTestModel + `","object":"model"},{"id":"moe-user-secret:latest","object":"model"}]}`
}

func startRawServer(t *testing.T, deps Deps) string {
	t.Helper()
	srv := khttp.NewServer(khttp.Address("127.0.0.1:0"))
	RegisterLLMRawHTTP(srv, deps)

	ep, err := srv.Endpoint()
	if err != nil {
		t.Fatalf("取监听地址失败: %v", err)
	}
	base := ep.String()

	startErr := make(chan error, 1)
	go func() { startErr <- srv.Start(context.Background()) }()
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = srv.Stop(ctx)
	})

	waitForPort(t, base)
	select {
	case err := <-startErr:
		if err != nil {
			t.Fatalf("服务启动即退出: %v", err)
		}
	default:
	}
	return base
}

func waitForPort(t *testing.T, base string) {
	t.Helper()
	addr := strings.TrimPrefix(strings.TrimPrefix(base, "http://"), "https://")
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 100*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("服务在 %s 上始终不可达", base)
}
