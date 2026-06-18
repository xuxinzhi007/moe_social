//go:build ignore

// admin-inline-handlers inlines api/internal/logic/admin into handler/admin.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"net/http"
	"backend/api/internal/handler/handlerutil"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func ` + funcName + `(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp := handlerutil.AdminRuntimeOverview(r.Context(), svcCtx)
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}
`
}

func authBlock(hs, respType string) ([]string, string) {
	if strings.Contains(hs, "PrepareAdminContext") {
		return []string{
			"\t\tctx, ok := common.PrepareAdminContext(w, r)",
			"\t\tif !ok {",
			"\t\t\treturn",
			"\t\t}",
		}, "ctx"
	}
	if strings.Contains(hs, "claims, br := common.RequireAdminToken") {
		return []string{
			"\t\tclaims, br := common.RequireAdminToken(r)",
			"\t\tif br != nil {",
			fmt.Sprintf("\t\t\thttpx.OkJsonCtx(r.Context(), w, &types.%s{BaseResp: *br})", respType),
			"\t\t\treturn",
			"\t\t}",
		}, "r.Context()"
	}
	if strings.Contains(hs, "RequireAdminToken") {
		return []string{
			"\t\tif _, br := common.RequireAdminToken(r); br != nil {",
			fmt.Sprintf("\t\t\thttpx.OkJsonCtx(r.Context(), w, &types.%s{BaseResp: *br})", respType),
			"\t\t\treturn",
			"\t\t}",
		}, "r.Context()"
	}
	return nil, "r.Context()"
}

func fixChatNotify(s string) string {
	s = strings.ReplaceAll(s, `HANDLERUTIL_SEND_PLACEHOLDER{
			UserID: `, `handlerutil.SendWSNotification(`)
	s = strings.ReplaceAll(s, `HANDLERUTIL_BROADCAST_PLACEHOLDER{
			Type: `, `handlerutil.BroadcastWSNotification(`)
	// collapse struct literal to (userID, type, data) — fix send/broadcast handlers manually below if needed
	return s
}

func sortImportsSet(imp []string) []string {
	set := map[string]bool{}
	for _, i := range imp {
		set[i] = true
	}
	var out []string
	for k := range set {
		out = append(out, k)
	}
	sort.Slice(out, func(i, j int) bool {
		bi := strings.HasPrefix(out[i], `"backend/`)
		bj := strings.HasPrefix(out[j], `"backend/`)
		if bi != bj {
			return bi
		}
		return out[i] < out[j]
	})
	return out
}

func indentBody(body, ctxExpr, prefix string) string {
	body = strings.ReplaceAll(body, "l.svcCtx", "svcCtx")
	body = strings.ReplaceAll(body, "l.ctx", ctxExpr)
	body = strings.ReplaceAll(body, "l.Errorf(", "logx.WithContext("+ctxExpr+").Errorf(")
	body = strings.ReplaceAll(body, "parseAdminPathID(", "handlerutil.ParseAdminPathID(")
	var b strings.Builder
	for _, raw := range strings.Split(body, "\n") {
		if strings.TrimSpace(raw) == "" {
			b.WriteString("\n")
			continue
		}
		b.WriteString(prefix + strings.TrimLeft(raw, "\t") + "\n")
	}
	return b.String()
}

func findLogicBody(typeName, methodName string) (string, string, string, string, error) {
	entries, _ := os.ReadDir(logicDir)
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".go") {
			continue
		}
		path := filepath.Join(logicDir, e.Name())
		src, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		s := string(src)
		if !strings.Contains(s, "type "+typeName+" struct") {
			continue
		}
		body, retType := extractMethodBody(s, typeName, methodName)
		if body == "" {
			return "", "", "", "", fmt.Errorf("method %s on %s", methodName, typeName)
		}
		helpers := extractHelpers(s, typeName)
		return path, body, helpers, retType, nil
	}
	return "", "", "", "", fmt.Errorf("logic for %s", typeName)
}

func extractMethodBody(src, typeName, methodName string) (string, string) {
	retType := ""
	sigLine := regexp.MustCompile(`func \(l \*` + regexp.QuoteMeta(typeName) + `\) ` + regexp.QuoteMeta(methodName) + `\([^)]*\)[^{]+`).FindString(src)
	if sigLine != "" {
		all := regexp.MustCompile(`\*types\.(\w+Resp)`).FindAllStringSubmatch(sigLine, -1)
		if len(all) > 0 {
			retType = all[len(all)-1][1]
		}
	}
	pat := regexp.MustCompile(`func \(l \*` + regexp.QuoteMeta(typeName) + `\) ` + regexp.QuoteMeta(methodName) + `\([^)]*\)[^{]*\{`)
	loc := pat.FindStringIndex(src)
	if loc == nil {
		return "", retType
	}
	i, depth := loc[1], 1
	for i < len(src) && depth > 0 {
		switch src[i] {
		case '{':
			depth++
		case '}':
			depth--
		}
		i++
	}
	return strings.TrimSpace(src[loc[1] : i-1]), retType
}

func extractHelpers(src, typeName string) string {
	skip := map[string]bool{"parseAdminPathID": true}
	var parts []string
	re := regexp.MustCompile(`(?m)^func ([A-Za-z]\w*)\(`)
	for _, m := range re.FindAllStringSubmatchIndex(src, -1) {
		name := src[m[2]:m[3]]
		if strings.HasPrefix(name, "New") || skip[name] {
			continue
		}
		fn := extractFreeFunc(src, name)
		if fn != "" {
			parts = append(parts, fn)
		}
	}
	return strings.Join(parts, "\n")
}

func extractFreeFunc(src, name string) string {
	pat := regexp.MustCompile(`(?m)^func ` + regexp.QuoteMeta(name) + `\([^)]*\)[^{]*\{`)
	loc := pat.FindStringIndex(src)
	if loc == nil {
		return ""
	}
	i, depth := loc[1], 1
	for i < len(src) && depth > 0 {
		switch src[i] {
		case '{':
			depth++
		case '}':
			depth--
		}
		i++
	}
	return strings.TrimSpace(src[loc[0]:i])
}

func collectImports(chunks ...string) []string {
	text := strings.Join(chunks, "\n")
	set := map[string]bool{
		`"net/http"`: true, `"backend/internal/platform/svc"`: true,
		`"backend/internal/legacy/types"`: true, `"github.com/zeromicro/go-zero/rest/httpx"`: true,
	}
	rules := []struct{ rx, imp string }{
		{`\bcommon\.`, `"backend/internal/apilegacy/common"`},
		{`\bhandlerutil\.`, `"backend/api/internal/handler/handlerutil"`},
		{`\bmoebridge\.`, `"backend/internal/apilegacy/moebridge"`},
		{`\bmoe\.`, `"backend/rpc/pb/moe"`},
		{`\butils\.`, `"backend/utils"`},
		{`\bmodel\.`, `"backend/model"`},
		{`\bruntime\.`, `"backend/pkg/moe/runtime"`},
		{`\bbrain\.`, `"backend/pkg/moe/brain"`},
		{`\bllminference\.`, `"backend/pkg/llminference"`},
		{`\bvipbiz\.`, `vipbiz "backend/internal/biz/vip"`},
		{`\bmoeadmin\.`, `moeadmin "backend/internal/service/moe"`},
		{`\bmoebiz\.`, `moebiz "backend/internal/biz/moe"`},
		{`\btoolaudit\.`, `"backend/pkg/moe/toolaudit"`},
		{`\btools\.`, `"backend/pkg/moe/tools"`},
		{`\bcore\.`, `"backend/pkg/moe/core"`},
		{`logx\.`, `"github.com/zeromicro/go-zero/core/logx"`},
		{`strings\.`, `"strings"`}, {`strconv\.`, `"strconv"`}, {`fmt\.`, `"fmt"`},
		{`context\.`, `"context"`}, {`time\.`, `"time"`},
		{`json\.`, `"encoding/json"`}, {`io\.`, `"io"`},
	}
	for _, r := range rules {
		if regexp.MustCompile(r.rx).MatchString(text) {
			set[r.imp] = true
		}
	}
	var imp []string
	for k := range set {
		imp = append(imp, k)
	}
	sort.Slice(imp, func(i, j int) bool {
		bi := strings.HasPrefix(imp[i], `"backend/`)
		bj := strings.HasPrefix(imp[j], `"backend/`)
		if bi != bj {
			return bi
		}
		return imp[i] < imp[j]
	})
	return imp
}

func submatch(p, s string) string {
	m := regexp.MustCompile(p).FindStringSubmatch(s)
	if len(m) > 1 {
		return m[1]
	}
	return ""
}
