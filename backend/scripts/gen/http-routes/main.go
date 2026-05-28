// 从 api/internal/handler/routes.go 生成 api/moehttp 路由注册。
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type routeEntry struct {
	method  string
	path    string
	handler string
}

var bridgePathPrefixes = []string{
	"/swagger",
}

var skipExactPaths = map[string]struct{}{
	"/api/admin/moe/runtimes":            {},
	"/api/admin/moe/brain/pipeline":      {},
	"/api/admin/dashboard":               {},
	"/api/admin/growth/stats":            {},
	"/api/admin/schema/catalog":          {},
	"/api/admin/ai/chat/sessions":        {},
	"/api/admin/ai/chat/messages":        {},
	"/api/admin/ai/chat/messages/export": {},
	"/api/admin/analytics/overview":      {},
	"/api/admin/topic-tags":              {},
	"/api/admin/vip/plans":               {},
	"/api/llm/models":                    {},
	"/api/llm/local-models/catalog":      {},
	"/api/landing/feedback":              {},
	"/api/ops/landing/feedback":          {},
	"/api/admin/landing/feedback":        {},
	// 波次1：internal/service + moehttp compat（见 api/moehttp/*_compat.go）
	"/api/user/:user_id/check-in":                    {},
	"/api/user/:user_id/level":                       {},
	"/api/user/:user_id/check-in/status":             {},
	"/api/user/:user_id/check-in/history":            {},
	"/api/user/:user_id/exp/logs":                    {},
	"/api/admin/growth/check-in-rewards":             {},
	"/api/admin/growth/check-in-rewards/:reward_id":  {},
	"/api/user/:user_id/achievements":                {},
	"/api/user/:user_id/achievements/unlocked":       {},
	"/api/user/:user_id/achievements/summary":        {},
	"/api/user/:user_id/achievements/ensure":         {},
	"/api/user/:user_id/behavior/events":             {},
	"/api/gifts":                                     {},
	"/api/gifts/:gift_id":                            {},
	"/api/user/:user_id/gifts/send":                  {},
	"/api/user/:user_id/gifts/records":               {},
	"/api/user/:user_id/gifts/purchase-orders":       {},
	"/api/user/:user_id/gifts/purchase":              {},
	"/api/comments":                                  {},
	"/api/comments/:comment_id/like":                 {},
	// 波次2：user/community/ai/chat 等（见 user_compat、community_compat、ai_compat、chat_compat、wave2_misc_compat）
	"/api/auth/feishu/authorize-url":                              {},
	"/api/auth/feishu/callback":                                   {},
	"/api/auth/feishu/login":                                      {},
	"/api/auth/feishu/public-config":                              {},
	"/api/auth/wechat/authorize-url":                              {},
	"/api/auth/wechat/callback":                                   {},
	"/api/auth/wechat/login":                                      {},
	"/api/transactions/:transaction_id":                           {},
	"/api/user/:follower_id/follow/:following_id/check":           {},
	"/api/user/:user_id":                                          {},
	"/api/user/:user_id/detail":                                   {},
	"/api/user/:user_id/devices":                                  {},
	"/api/user/:user_id/devices/sync":                             {},
	"/api/user/:user_id/follow":                                   {},
	"/api/user/:user_id/followers":                                {},
	"/api/user/:user_id/following":                                {},
	"/api/user/:user_id/friend-requests":                          {},
	"/api/user/:user_id/friend-requests/:request_id/accept":       {},
	"/api/user/:user_id/friend-requests/:request_id/reject":       {},
	"/api/user/:user_id/friend-requests/incoming":                 {},
	"/api/user/:user_id/friend-requests/outgoing":                 {},
	"/api/user/:user_id/friends":                                  {},
	"/api/user/:user_id/friends/status/:other_user_id":          {},
	"/api/user/:user_id/memories":                                 {},
	"/api/user/:user_id/memories/display":                         {},
	"/api/user/:user_id/memories/feedback":                        {},
	"/api/user/:user_id/memories/profiles":                        {},
	"/api/user/:user_id/memories/reindex":                         {},
	"/api/user/:user_id/memories/search":                          {},
	"/api/user/:user_id/password":                                 {},
	"/api/user/:user_id/transactions":                             {},
	"/api/user/:user_id/vip":                                      {},
	"/api/user/:user_id/vip/active":                               {},
	"/api/user/:user_id/vip/auto-renew":                           {},
	"/api/user/:user_id/vip/check":                                {},
	"/api/user/:user_id/vip/orders":                               {},
	"/api/user/:user_id/vip/records":                              {},
	"/api/user/:user_id/vip/sync":                                 {},
	"/api/user/:user_id/wallet/recharge":                          {},
	"/api/user/check-email":                                       {},
	"/api/user/login":                                             {},
	"/api/user/refresh-token":                                     {},
	"/api/user/register":                                          {},
	"/api/user/reset-password":                                    {},
	"/api/users":                                                  {},
	"/api/users/count":                                            {},
	"/api/user/account":                                           {},
	"/api/user/feishu/bind":                                       {},
	"/api/user/feishu/test-card":                                  {},
	"/api/admin/bootstrap/account":                                {},
	"/api/admin/login":                                            {},
	"/api/ai/agents":                                              {},
	"/api/ai/agents/public":                                       {},
	"/api/ai/config":                                              {},
	"/api/ai/lorebooks":                                           {},
	"/api/ai/memory/settings":                                     {},
	"/api/ai/providers":                                           {},
	"/api/avatar/:user_id":                                        {},
	"/api/avatar/outfits":                                         {},
	"/api/avatar/outfits/:outfit_id":                              {},
	"/api/avatar/outfits/:outfit_id/purchase":                     {},
	"/api/chat/online":                                            {},
	"/api/chat/online/batch":                                      {},
	"/ws/chat":                                                    {},
	"/ws/presence":                                                {},
	"/ws/remote":                                                  {},
	"/ws/world":                                                   {},
	"/api/community/groups":                                       {},
	"/api/community/groups/:group_id":                             {},
	"/api/community/groups/:group_id/join":                        {},
	"/api/community/groups/:group_id/leave":                       {},
	"/api/community/groups/:group_id/members":                     {},
	"/api/community/groups/:group_id/posts":                       {},
	"/api/user/:user_id/community/groups":                         {},
	"/api/content/generate":                                       {},
	"/api/emoji/packs":                                            {},
	"/api/emoji/packs/:pack_id":                                   {},
	"/api/emoji/packs/:pack_id/favorite":                          {},
	"/api/emoji/packs/:pack_id/purchase":                          {},
	"/api/user/:user_id/emoji/packs":                              {},
	"/api/images":                                                 {},
	"/api/images/:filename":                                       {},
	"/api/upload":                                                 {},
	"/api/notification/broadcast":                                 {},
	"/api/notification/send":                                      {},
	"/api/notification/send-batch":                                {},
	"/api/notifications":                                          {},
	"/api/notifications/:id/read":                                 {},
	"/api/notifications/read-all":                                 {},
	"/api/notifications/unread":                                   {},
	"/api/posts":                                                  {},
	"/api/posts/:post_id":                                         {},
	"/api/posts/:post_id/comments":                                {},
	"/api/posts/:post_id/like":                                    {},
	"/api/posts/:post_id/report":                                  {},
	"/api/posts/search":                                           {},
	"/api/private-messages":                                       {},
	"/api/private-messages/conversations":                         {},
	"/api/vip/plans":                                              {},
	"/api/vip/plans/:plan_id":                                     {},
	// 波次3：admin + platform（见 admin_service_compat、admin_legacy_compat、platform_compat）
	"/api/admin/accounts":                         {},
	"/api/admin/accounts/:account_id":               {},
	"/api/admin/achievements/bootstrap":             {},
	"/api/admin/ai/agents":                          {},
	"/api/admin/announcements":                      {},
	"/api/admin/announcements/:announcement_id":     {},
	"/api/admin/announcements/:announcement_id/publish": {},
	"/api/admin/audit-logs":                         {},
	"/api/admin/comments":                           {},
	"/api/admin/comments/:comment_id":               {},
	"/api/admin/community/groups":                   {},
	"/api/admin/community/groups/:group_id":         {},
	"/api/admin/gifts":                              {},
	"/api/admin/gifts/:gift_id":                     {},
	"/api/admin/gifts/bootstrap":                    {},
	"/api/admin/gifts/dedupe":                       {},
	"/api/admin/growth/achievements":                {},
	"/api/admin/growth/achievements/:achievement_id": {},
	"/api/admin/growth/levels":                      {},
	"/api/admin/growth/levels/:level_id":            {},
	"/api/admin/growth/levels/bootstrap":            {},
	"/api/admin/me":                                 {},
	"/api/admin/media/images":                       {},
	"/api/admin/media/images/:filename":             {},
	"/api/admin/memories":                           {},
	"/api/admin/memories/:memory_id":                {},
	"/api/admin/memories/stats":                     {},
	"/api/admin/menus":                              {},
	"/api/admin/menus/:menu_key":                    {},
	"/api/admin/menus/bootstrap":                    {},
	"/api/admin/moe/brain/episodes/:id":             {},
	"/api/admin/moe/brain/episodes/:id/refine":      {},
	"/api/admin/moe/brain/pipeline/stream":          {},
	"/api/admin/moe/inference/status":               {},
	"/api/admin/moe/runtimes/:agent_key/brain":      {},
	"/api/admin/moe/runtimes/:agent_key/brain/curate": {},
	"/api/admin/moe/runtimes/:agent_key/brain/policy": {},
	"/api/admin/moe/runtimes/:agent_key/flow":       {},
	"/api/admin/moe/runtimes/:agent_key/run-once":   {},
	"/api/admin/moe/tools/calls":                    {},
	"/api/admin/moe/tools/schema":                   {},
	"/api/admin/moe/tools/stats":                    {},
	"/api/admin/notifications/broadcast":            {},
	"/api/admin/notifications/send":                 {},
	"/api/admin/orders/gift-purchase":               {},
	"/api/admin/orders/vip":                         {},
	"/api/admin/post-reports":                       {},
	"/api/admin/posts":                              {},
	"/api/admin/posts/:post_id":                     {},
	"/api/admin/runtime-config":                     {},
	"/api/admin/runtime/overview":                   {},
	"/api/admin/social/follows":                     {},
	"/api/admin/social/follows/:follow_id":          {},
	"/api/admin/social/friend-requests":             {},
	"/api/admin/tag-dictionary":                     {},
	"/api/admin/tag-dictionary/:entry_id":           {},
	"/api/admin/topic-tags/:tag_id":                 {},
	"/api/admin/topic-tags/bootstrap":               {},
	"/api/admin/users":                              {},
	"/api/admin/users/:user_id":                     {},
	"/api/admin/users/:user_id/profile":             {},
	"/api/admin/vip/plans/:plan_id":                 {},
	"/api/admin/vip/plans/bootstrap":                {},
	"/api/public/client-config":                     {},
	"/api/user/:user_id/content":                    {},
	"/api/llm/agents":                               {},
	"/api/llm/chat":                                 {},
	"/api/llm/chat/raw":                             {},
	"/api/llm/config":                               {},
	"/api/llm/models/delete":                        {},
	"/api/llm/models/download":                      {},
	"/api/llm/models/raw":                           {},
	"/api/llm/show/raw":                             {},
	"/api/moe/tools/execute":                        {},
	"/api/moe/tools/schema":                         {},
	"/api/voice/answer":                             {},
	"/api/voice/call":                               {},
	"/api/voice/cancel":                             {},
	"/api/voice/reject":                             {},
	"/api/voice/token":                              {},
}

func main() {
	root := backendRoot()
	routesPath := filepath.Join(root, "api/internal/handler/routes.go")
	nativeOut := filepath.Join(root, "api/moehttp/routes_native_gen.go")
	bridgeOut := filepath.Join(root, "api/moehttp/routes_bridge_gen.go")

	entries, err := parseRoutes(routesPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "parse routes: %v\n", err)
		os.Exit(1)
	}

	var native, bridge []routeEntry
	for _, e := range entries {
		if isBridgeRoute(e.path) {
			bridge = append(bridge, e)
		} else if !isCompatOnlyPath(e.path) {
			native = append(native, e)
		}
	}

	if err := writeNativeFile(nativeOut, native); err != nil {
		fmt.Fprintf(os.Stderr, "write native: %v\n", err)
		os.Exit(1)
	}
	if err := writeBridgeFile(bridgeOut, bridge); err != nil {
		fmt.Fprintf(os.Stderr, "write bridge: %v\n", err)
		os.Exit(1)
	}
	removeObsoleteFiles(root)
	fmt.Printf("OK: native=%d bridge=%d compat_skip=%d total=%d → api/moehttp\n",
		len(native), len(bridge), len(skipExactPaths), len(entries))
}

func backendRoot() string {
	if root := strings.TrimSpace(os.Getenv("MOE_BACKEND_ROOT")); root != "" {
		return root
	}
	wd, _ := os.Getwd()
	for d := wd; d != filepath.Dir(d); d = filepath.Dir(d) {
		if _, err := os.Stat(filepath.Join(d, "go.mod")); err == nil {
			if _, err2 := os.Stat(filepath.Join(d, "Makefile")); err2 == nil {
				return d
			}
		}
	}
	return wd
}

func removeObsoleteFiles(root string) {
	dir := filepath.Join(root, "api/moehttp")
	for _, name := range []string{"routes_handlers_gen.go", "get_handlers_gen.go"} {
		_ = os.Remove(filepath.Join(dir, name))
	}
}

func isCompatOnlyPath(path string) bool {
	_, ok := skipExactPaths[path]
	return ok
}

func isBridgeRoute(path string) bool {
	if isCompatOnlyPath(path) {
		return false
	}
	for _, p := range bridgePathPrefixes {
		if path == p || strings.HasPrefix(path, p) {
			return true
		}
	}
	return false
}

func parseRoutes(path string) ([]routeEntry, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	blockRe := regexp.MustCompile(`(?s)Method:\s+(http\.Method\w+),\s*Path:\s+"([^"]+)",\s*Handler:\s+(\w+)\.(\w+)\(serverCtx\)`)
	matches := blockRe.FindAllStringSubmatch(string(raw), -1)
	var entries []routeEntry
	for _, m := range matches {
		if len(m) != 5 {
			continue
		}
		kmethod := goZeroMethodToKratos(m[1])
		if kmethod == "" {
			continue
		}
		entries = append(entries, routeEntry{
			method:  kmethod,
			path:    m[2],
			handler: m[3] + "." + m[4],
		})
	}
	return entries, nil
}

func writeNativeFile(outPath string, entries []routeEntry) error {
	importSet := map[string]struct{}{}
	for _, e := range entries {
		pkg := strings.SplitN(e.handler, ".", 2)[0]
		importSet[pkg] = struct{}{}
	}
	pkgs := sortedKeys(importSet)

	var b strings.Builder
	b.WriteString("// Code generated by scripts/gen/http-routes; DO NOT EDIT.\n\n")
	b.WriteString("package moehttp\n\n")
	if len(pkgs) == 0 {
		b.WriteString("import (\n\t\"backend/api/internal/svc\"\n\n\tkhttp \"github.com/go-kratos/kratos/v2/transport/http\"\n)\n\n")
	} else {
		b.WriteString("import (\n\t\"backend/api/internal/svc\"\n")
		for _, p := range pkgs {
			b.WriteString(fmt.Sprintf("\t%s \"backend/api/internal/handler/%s\"\n", handlerImportAlias(p), p))
		}
		b.WriteString("\n\tkhttp \"github.com/go-kratos/kratos/v2/transport/http\"\n)\n\n")
	}
	b.WriteString(fmt.Sprintf("const nativeDomainRouteCount = %d\n\n", len(entries)))
	b.WriteString("func RegisterNativeDomainHTTPHandlers(srv *khttp.Server, svc *svc.ServiceContext) {\n")
	b.WriteString("\tif srv == nil || svc == nil {\n\t\treturn\n\t}\n")
	if len(entries) == 0 {
		b.WriteString("\treturn\n")
	} else {
		b.WriteString("\tr := srv.Route(\"/\")\n")
		for _, e := range entries {
			parts := strings.SplitN(e.handler, ".", 2)
			if len(parts) != 2 {
				continue
			}
			b.WriteString(fmt.Sprintf("\tr.%s(%q, wrapNativeHTTP(%s.%s(svc)))\n",
				e.method, e.path, handlerImportAlias(parts[0]), parts[1]))
		}
	}
	b.WriteString("}\n")
	return os.WriteFile(outPath, []byte(b.String()), 0o644)
}

func writeBridgeFile(outPath string, entries []routeEntry) error {
	importSet := map[string]struct{}{}
	for _, e := range entries {
		pkg := strings.SplitN(e.handler, ".", 2)[0]
		importSet[pkg] = struct{}{}
	}
	pkgs := sortedKeys(importSet)

	var b strings.Builder
	b.WriteString("// Code generated by scripts/gen/http-routes; DO NOT EDIT.\n\n")
	b.WriteString("package moehttp\n\n")
	if len(pkgs) == 0 {
		b.WriteString("import (\n\t\"backend/api/internal/svc\"\n\n\tkhttp \"github.com/go-kratos/kratos/v2/transport/http\"\n)\n\n")
	} else {
		b.WriteString("import (\n\t\"backend/api/internal/svc\"\n")
		for _, p := range pkgs {
			b.WriteString(fmt.Sprintf("\t%s \"backend/api/internal/handler/%s\"\n", handlerImportAlias(p), p))
		}
		b.WriteString("\n\tkhttp \"github.com/go-kratos/kratos/v2/transport/http\"\n)\n\n")
	}
	b.WriteString(fmt.Sprintf("const bridgeRouteCount = %d\n\n", len(entries)))
	b.WriteString("func RegisterBridgeHTTPHandlers(srv *khttp.Server, svc *svc.ServiceContext) {\n")
	b.WriteString("\tif srv == nil || svc == nil {\n\t\treturn\n\t}\n")
	if len(entries) == 0 {
		b.WriteString("\treturn\n")
	} else {
		b.WriteString("\tr := srv.Route(\"/\")\n")
		for _, e := range entries {
			parts := strings.SplitN(e.handler, ".", 2)
			if len(parts) != 2 {
				continue
			}
			b.WriteString(fmt.Sprintf("\tr.%s(%q, wrapGoZeroHandler(%s.%s(svc)))\n",
				e.method, e.path, handlerImportAlias(parts[0]), parts[1]))
		}
	}
	b.WriteString("}\n")
	return os.WriteFile(outPath, []byte(b.String()), 0o644)
}

func sortedKeys(m map[string]struct{}) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func goZeroMethodToKratos(methodConst string) string {
	switch methodConst {
	case "http.MethodGet":
		return "GET"
	case "http.MethodPost":
		return "POST"
	case "http.MethodPut":
		return "PUT"
	case "http.MethodDelete":
		return "DELETE"
	case "http.MethodPatch":
		return "PATCH"
	case "http.MethodHead":
		return "HEAD"
	case "http.MethodOptions":
		return "OPTIONS"
	default:
		return ""
	}
}

func handlerImportAlias(pkg string) string {
	var b strings.Builder
	b.WriteByte('h')
	for _, r := range pkg {
		if r == '_' {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}
