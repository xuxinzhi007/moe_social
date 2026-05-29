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
)

var (
	skipHandlers = map[string]bool{
		"adminlistlandingfeedbackhandler.go":     true,
		"adminstreammoebrainpipelinehandler.go":  true,
	}
	handlerDir = filepath.Join("api", "internal", "handler", "admin")
	logicDir   = filepath.Join("api", "internal", "logic", "admin")
)

var collectedHelpers = map[string]string{}

func main() {
	if err := os.Chdir(findBackend()); err != nil {
		fmt.Fprintf(os.Stderr, "chdir: %v\n", err)
		os.Exit(1)
	}
	ok, failed := 0, map[string]string{}
	entries, _ := os.ReadDir(handlerDir)
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), "handler.go") {
			continue
		}
		if skipHandlers[e.Name()] || e.Name() == "helpers_gen.go" {
			continue
		}
		path := filepath.Join(handlerDir, e.Name())
		st, err := migrate(path)
		if err != nil {
			failed[e.Name()] = err.Error()
			continue
		}
		if st == "ok" {
			ok++
		}
	}
	if len(collectedHelpers) > 0 {
		writeHelpersFile()
	}
	fmt.Printf("ok=%d failed=%d helpers=%d\n", ok, len(failed), len(collectedHelpers))
	for k, v := range failed {
		fmt.Printf("  %s: %s\n", k, v)
	}
	if len(failed) > 0 {
		os.Exit(1)
	}
}

func writeHelpersFile() {
	var names []string
	for n := range collectedHelpers {
		names = append(names, n)
	}
	sort.Strings(names)
	var b strings.Builder
	b.WriteString("package admin\n\nimport (\n")
	b.WriteString("\t\"backend/api/internal/common\"\n")
	b.WriteString("\t\"backend/api/internal/svc\"\n")
	b.WriteString("\t\"backend/api/internal/types\"\n")
	b.WriteString("\t\"backend/utils\"\n")
	b.WriteString("\t\"strconv\"\n")
	b.WriteString("\t\"strings\"\n")
	b.WriteString(")\n\n")
	for _, n := range names {
		b.WriteString(collectedHelpers[n])
		b.WriteString("\n\n")
	}
	_ = os.WriteFile(filepath.Join(handlerDir, "helpers_gen.go"), []byte(b.String()), 0o644)
}

func findBackend() string {
	wd, _ := os.Getwd()
	for dir := wd; ; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			if _, err2 := os.Stat(filepath.Join(dir, "api", "internal")); err2 == nil {
				return dir
			}
		}
		if filepath.Dir(dir) == dir {
			return wd
		}
	}
}

func migrate(handlerPath string) (string, error) {
	hsrc, err := os.ReadFile(handlerPath)
	if err != nil {
		return "", err
	}
	hs := string(hsrc)
	funcName := submatch(`func (Admin\w+Handler)\(`, hs)
	if funcName == "" {
		return "", fmt.Errorf("parse handler")
	}
	ctor := submatch(`admin\.(New\w+Logic)\(`, hs)
	if ctor == "" {
		// AdminDashboardHandler -> NewAdminDashboardLogic
		base := strings.TrimSuffix(funcName, "Handler")
		ctor = "New" + base + "Logic"
	}
	typeName := strings.TrimPrefix(ctor, "New")
	methodName := strings.TrimSuffix(typeName, "Logic")
	logicPath, body, helpers, logicRespType, err := findLogicBody(typeName, methodName)
	if err != nil {
		return "", err
	}
	_ = logicPath

	reqType := submatch(`var req types\.(\w+)`, hs)
	respType := logicRespType
	if respType == "" {
		respType = methodName + "Resp"
	}
	callArg := submatch(`l\.\w+\(([^)]*)\)`, hs)

	if funcName == "AdminRuntimeOverviewHandler" {
		out := runtimeHandler(funcName)
		return "ok", os.WriteFile(handlerPath, []byte(out), 0o644)
	}

	auth, ctxExpr := authBlock(hs, respType)
	sigLine := ""
	if logicPath != "" {
		if raw, e := os.ReadFile(logicPath); e == nil {
			sigLine = regexp.MustCompile(`func \(l \*` + regexp.QuoteMeta(typeName) + `\) ` + regexp.QuoteMeta(methodName) + `\([^)]*\)[^{]+`).FindString(string(raw))
		}
	}
	namedReturn := strings.Contains(sigLine, "(resp *types.")
	inlined := indentBody(body, ctxExpr, "\t\t\t")
	imp := collectImports(body, helpers, hs)

	var b strings.Builder
	b.WriteString("package admin\n\nimport (\n")
	for _, im := range imp {
		b.WriteString("\t" + im + "\n")
	}
	b.WriteString(")\n\n")
	fmt.Fprintf(&b, "func %s(svcCtx *svc.ServiceContext) http.HandlerFunc {\n", funcName)
	b.WriteString("\treturn func(w http.ResponseWriter, r *http.Request) {\n")
	for _, ln := range auth {
		b.WriteString(ln + "\n")
	}
	if reqType != "" {
		fmt.Fprintf(&b, "\t\tvar req types.%s\n", reqType)
		b.WriteString("\t\tif err := httpx.Parse(r, &req); err != nil {\n")
		fmt.Fprintf(&b, "\t\t\thttpx.ErrorCtx(%s, w, err)\n", ctxExpr)
		b.WriteString("\t\t\treturn\n\t\t}\n")
	}
	if callArg == "claims" {
		if namedReturn {
			fmt.Fprintf(&b, "\t\tresp, err := func(claims *utils.AdminClaims) (resp *types.%s, err error) {\n", respType)
		} else {
			fmt.Fprintf(&b, "\t\tresp, err := func(claims *utils.AdminClaims) (*types.%s, error) {\n", respType)
		}
		b.WriteString(inlined)
		b.WriteString("\t\t}(claims)\n")
	} else if reqType != "" {
		if namedReturn {
			fmt.Fprintf(&b, "\t\tresp, err := func(req *types.%s) (resp *types.%s, err error) {\n", reqType, respType)
		} else {
			fmt.Fprintf(&b, "\t\tresp, err := func(req *types.%s) (*types.%s, error) {\n", reqType, respType)
		}
		b.WriteString(inlined)
		b.WriteString("\t\t}(&req)\n")
	} else {
		if namedReturn {
			fmt.Fprintf(&b, "\t\tresp, err := func() (resp *types.%s, err error) {\n", respType)
		} else {
			fmt.Fprintf(&b, "\t\tresp, err := func() (*types.%s, error) {\n", respType)
		}
		b.WriteString(inlined)
		b.WriteString("\t\t}()\n")
	}
	b.WriteString("\t\tif err != nil {\n")
	fmt.Fprintf(&b, "\t\t\thttpx.ErrorCtx(%s, w, err)\n", ctxExpr)
	b.WriteString("\t\t} else {\n")
	fmt.Fprintf(&b, "\t\t\thttpx.OkJsonCtx(%s, w, resp)\n", ctxExpr)
	b.WriteString("\t\t}\n\t}\n}\n")

	if helpers != "" {
		for _, fn := range strings.Split(helpers, "\n\n") {
			fn = strings.TrimSpace(fn)
			if fn == "" {
				continue
			}
			name := submatch(`^func (\w+)`, fn)
			if name != "" {
				collectedHelpers[name] = fn
			}
		}
	}
	return "ok", os.WriteFile(handlerPath, []byte(b.String()), 0o644)
}

func runtimeHandler(funcName string) string {
	return `package admin

import (
	"net/http"

	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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
		`"net/http"`: true, `"backend/api/internal/svc"`: true,
		`"backend/api/internal/types"`: true, `"github.com/zeromicro/go-zero/rest/httpx"`: true,
	}
	rules := []struct{ rx, imp string }{
		{`\bcommon\.`, `"backend/api/internal/common"`},
		{`\bhandlerutil\.`, `"backend/api/internal/handler/handlerutil"`},
		{`\bmoebridge\.`, `"backend/api/internal/moebridge"`},
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
