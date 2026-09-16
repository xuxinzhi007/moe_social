package platformhttp

import (
	"context"
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

// 三个 Ollama 透传端点必须是原生路由，不能改回 proto RPC。
// 每条断言都对应 proto 路线上的一个必然故障，把它换回去这个测试就会红：
//   - 状态码 418 原样透传：proto 路线会把响应编码成 200 + JSON 信封；
//   - 请求体完整抵达推理端：proto handler 的 ctx.Bind(&in) 会先把 body 读干；
//   - 客户端拿到推理端的响应体：proto handler 的 out.(*LlmRawProxyResp) 对 nil 接口断言必 panic；
//   - 命中正确的推理路径：确认三条路由没有互相串。
func TestLLMRawRoutesPassThroughBodyAndResponse(t *testing.T) {
	cases := []struct {
		name       string
		method     string
		route      string
		wantTarget string
		body       string
	}{
		{"chat", http.MethodPost, "/api/llm/chat/raw", "/v1/chat/completions", `{"model":"qwen2.5","messages":[{"role":"user","content":"你好"}]}`},
		{"models", http.MethodGet, "/api/llm/models/raw", "/v1/models", ""},
		{"show", http.MethodPost, "/api/llm/show/raw", "/v1/models/", `{"model":"qwen2.5"}`},
	}

	// LLMApp 非空与为空是两条不同的转发分支，都要覆盖。
	for _, withApp := range []bool{false, true} {
		branch := "biz"
		if withApp {
			branch = "app"
		}
		for _, tc := range cases {
			t.Run(branch+"/"+tc.name, func(t *testing.T) {
				var gotTarget, gotBody string
				fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					raw, _ := io.ReadAll(r.Body)
					gotTarget, gotBody = r.URL.Path, string(raw)
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusTeapot)
					_, _ = io.WriteString(w, `{"marker":"from-fake-inference"}`)
				}))
				defer fake.Close()

				deps := Deps{InferenceConfig: llminference.ConfigFrom(fake.URL, "openai", 30, "", "")}
				if withApp {
					deps.LLMApp = llmapp.New(nil, llmapp.Deps{Inference: deps.InferenceConfig})
				}
				base := startRawServer(t, deps)

				var bodyReader io.Reader
				if tc.body != "" {
					bodyReader = strings.NewReader(tc.body)
				}
				req, err := http.NewRequest(tc.method, base+tc.route, bodyReader)
				if err != nil {
					t.Fatalf("构造请求失败: %v", err)
				}
				resp, err := http.DefaultClient.Do(req)
				if err != nil {
					t.Fatalf("%s %s 请求失败（handler panic 会表现成这样）: %v", tc.method, tc.route, err)
				}
				defer resp.Body.Close()
				respBody, _ := io.ReadAll(resp.Body)

				if resp.StatusCode == http.StatusNotFound {
					t.Fatalf("%s 未注册成路由，拿到 404: %s", tc.route, respBody)
				}
				if resp.StatusCode != http.StatusTeapot {
					t.Errorf("推理端状态码未透传: 期望 418，实际 %d，body=%s", resp.StatusCode, respBody)
				}
				if !strings.Contains(string(respBody), "from-fake-inference") {
					t.Errorf("推理端响应体未回到客户端: %s", respBody)
				}
				if gotTarget != tc.wantTarget {
					t.Errorf("打到了错误的推理路径: 期望 %s，实际 %s", tc.wantTarget, gotTarget)
				}
				if gotBody != tc.body {
					t.Errorf("请求体没有完整透传: 期望 %q，实际 %q", tc.body, gotBody)
				}
			})
		}
	}
}

// 推理端没配置时必须返回错误而不是 panic，并且服务要还活着。
func TestLLMRawRoutesWithoutInferenceConfigStayAlive(t *testing.T) {
	base := startRawServer(t, Deps{})

	resp, err := http.Get(base + "/api/llm/models/raw")
	if err != nil {
		t.Fatalf("请求失败: %v", err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		t.Fatalf("路由未注册，拿到 404: %s", body)
	}
	if resp.StatusCode == http.StatusOK {
		t.Errorf("推理端未配置却返回 200: %s", body)
	}

	// 前一个请求出错后服务必须还能应答，否则说明它被打死了。
	probe, err := http.Get(base + "/api/llm/models/raw")
	if err != nil {
		t.Fatalf("第二次请求失败，服务已被打死: %v", err)
	}
	probe.Body.Close()
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
