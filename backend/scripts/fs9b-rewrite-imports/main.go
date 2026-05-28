// FS-9b phase 2: 将 backend/rpc/pb/super 引用迁为 backend/rpc/pb/moe（保留 shim 供外部兼容）。
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	oldImport = `"backend/rpc/pb/super"`
	newImport = `"backend/rpc/pb/moe"`
)

func main() {
	root := os.Getenv("MOE_BACKEND_ROOT")
	if root == "" {
		wd, _ := os.Getwd()
		if strings.HasSuffix(wd, "scripts/fs9b-rewrite-imports") {
			root = filepath.Join(wd, "../..")
		} else {
			root = wd
		}
	}
	var changed int
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}
		if !strings.HasSuffix(path, ".go") {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		if shouldSkip(rel) {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		body := string(raw)
		if !strings.Contains(body, oldImport) {
			return nil
		}
		next := strings.ReplaceAll(body, oldImport, newImport)
		next = rewriteSuperQualifier(next)
		if next == body {
			return nil
		}
		if err := os.WriteFile(path, []byte(next), info.Mode()); err != nil {
			return err
		}
		changed++
		fmt.Println("updated:", rel)
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "walk: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("OK: FS-9b rewritten %d files\n", changed)
}

// rewriteSuperQualifier 将类型前缀 super. 改为 moe.，保留字段名 g.super 等。
func rewriteSuperQualifier(body string) string {
	var b strings.Builder
	i := 0
	for i < len(body) {
		if i+6 <= len(body) && body[i:i+6] == "super." {
			prev := byte(' ')
			if i > 0 {
				prev = body[i-1]
			}
			if prev == '.' {
				b.WriteString("super.")
				i += 6
				continue
			}
			b.WriteString("moe.")
			i += 6
			continue
		}
		b.WriteByte(body[i])
		i++
	}
	return b.String()
}

func shouldSkip(rel string) bool {
	switch {
	case strings.HasPrefix(rel, "rpc/pb/super/"):
		return true
	case strings.HasPrefix(rel, "rpc/pb/moe/"):
		return true
	case strings.Contains(rel, "/vendor/"):
		return true
	case strings.HasPrefix(rel, "scripts/fs9b-rewrite-imports/"):
		return true
	default:
		return false
	}
}
