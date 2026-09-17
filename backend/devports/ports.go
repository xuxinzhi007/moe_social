// Package devports defines local dev tool ports for Moe Social.
//
// Block 19010–19019 is reserved for this repo to avoid clashes with common defaults:
// Flutter DevTools :9100, cpolar/go pprof :6060, generic docs :8765, etc.
// 本包同时登记外部推理依赖端口（GameInference/Ollama）：那些端口由外部进程监听，
// 本仓库只在 config.yaml 里配置读取，从不 bind。
package devports

import "strconv"

const (
	// AgentPort — deploy-agent / devtools hub (make deploy-agent).
	AgentPort = 19010
	// RpcDebugPort — reserved. The RPC -debug pprof provider was removed with the
	// go-zero rpc process, so nothing listens here; Agent still proxies /debug/* to it.
	RpcDebugPort = 19011
	// DocsStaticPort — optional static docs (make dev-docs); Agent hub replaces this in most flows.
	DocsStaticPort = 19012

	// GameInferencePort — 外部 llama-server（config.yaml llm_inference.game_base_url
	// 的 127.0.0.1:6633）。本仓库不监听；由开发者本机单独启动的推理进程占用。
	GameInferencePort = 6633
	// OllamaPort — 外部 Ollama（config.yaml llm_inference.base_url；llminference
	// 客户端也按 ":11434" 识别原生 Ollama API 风格）。本仓库不监听；地址可以是
	// loopback 也可以是局域网主机，取决于配置。
	OllamaPort = 11434

	AgentAddr    = "127.0.0.1:19010"
	RpcDebugAddr = "127.0.0.1:19011"
)

// RpcDebugUpstream is the HTTP base URL for RPC debug API.
func RpcDebugUpstream() string {
	return "http://" + RpcDebugAddr
}

// AgentURL is the devtools hub base URL.
func AgentURL() string {
	return "http://" + AgentAddr
}

// RpcDebugFallbackPorts returns RpcDebugPort and spares in 19011–19016.
func RpcDebugFallbackPorts() []int {
	out := make([]int, 0, 7)
	for p := RpcDebugPort; p <= RpcDebugPort+5; p++ {
		out = append(out, p)
	}
	return out
}

// DocsStaticPortStr for python -m http.server.
func DocsStaticPortStr() string {
	return strconv.Itoa(DocsStaticPort)
}

// AgentPortStr for dev launcher logs.
func AgentPortStr() string {
	return strconv.Itoa(AgentPort)
}

// RpcDebugPortStr for dev launcher logs.
func RpcDebugPortStr() string {
	return strconv.Itoa(RpcDebugPort)
}
