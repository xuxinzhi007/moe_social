package main

import (
	"go/format"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var getterByBiz = map[string]string{
	"adminbiz":     "l.svcCtx.AdminStore()",
	"notifybiz":    "l.svcCtx.NotifyStore()",
	"userbiz":      "l.svcCtx.UserStore()",
	"postbiz":      "l.svcCtx.PostStore()",
	"commentbiz":   "l.svcCtx.CommentStore()",
	"communitybiz": "l.svcCtx.CommunityStore()",
	"giftbiz":      "l.svcCtx.GiftStore()",
	"vipbiz":       "l.svcCtx.VipStore()",
	"chatbiz":      "l.svcCtx.ChatStore()",
	"behaviorbiz":  "l.svcCtx.BehaviorStore()",
	"llmbiz":       "l.svcCtx.MemoryStore()",
	"aibiz":        "l.svcCtx.AiStore()",
	"moebiz":       "l.svcCtx.MoeStore()",
}

func main() {
	root := filepath.Join("rpc", "internal", "logic")
	changed := 0
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(path, ".go") {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil || !bytesContains(raw, "l.svcCtx.DB") {
			return nil
		}
		out := string(raw)
		for biz, getter := range getterByBiz {
			re := regexp.MustCompile(`(?s)(` + regexp.QuoteMeta(biz) + `\.\w+\([^)]*?)l\.svcCtx\.DB`)
			out2 := re.ReplaceAllString(out, "${1}"+getter)
			out = out2
		}
		if out == string(raw) {
			return nil
		}
		formatted, err := format.Source([]byte(out))
		if err != nil {
			formatted = []byte(out)
		}
		if err := os.WriteFile(path, formatted, 0o644); err != nil {
			return err
		}
		changed++
		return nil
	})
	println("fixed files:", changed)
}

func bytesContains(b []byte, s string) bool {
	return strings.Contains(string(b), s)
}
