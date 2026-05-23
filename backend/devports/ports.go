// Package devports defines local dev tool ports for Moe Social (loopback only).
//
// Block 19010–19019 is reserved for this repo to avoid clashes with common defaults:
// Flutter DevTools :9100, cpolar/go pprof :6060, generic docs :8765, etc.
package devports

import "strconv"

const (
	// AgentPort — deploy-agent / devtools hub (make deploy-agent).
	AgentPort = 19010
	// RpcDebugPort — RPC -debug pprof API (make rpc-debug); Agent proxies /debug/* here.
	RpcDebugPort = 19011
	// DocsStaticPort — optional static docs (make dev-docs); Agent hub replaces this in most flows.
	DocsStaticPort = 19012

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
