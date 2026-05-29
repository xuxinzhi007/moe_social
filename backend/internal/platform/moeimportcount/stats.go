// Package moeimportcount tracks rpc/pb/moe import debt for Phase-2 migration metrics.
package moeimportcount

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const moeImportPath = "backend/rpc/pb/moe"

var moePbImportRE = regexp.MustCompile(`"` + regexp.QuoteMeta(moeImportPath) + `"`)

// BizMoeImportFileCount counts .go files under internal/biz that import rpc/pb/moe.
func BizMoeImportFileCount() int {
	return countMoeImports(filepath.Join("internal", "biz"))
}

// ApilegacyMoeImportFileCount counts .go files under internal/apilegacy that import rpc/pb/moe.
func ApilegacyMoeImportFileCount() int {
	return countMoeImports(filepath.Join("internal", "apilegacy"))
}

// Phase2BridgeRetiredPercent is 100 when biz and apilegacy no longer import rpc/pb/moe.
func Phase2BridgeRetiredPercent() int {
	if BizMoeImportFileCount() == 0 && ApilegacyMoeImportFileCount() == 0 {
		return 100
	}
	return 0
}

// RuntimeMoePbImportFileCount counts non-archive .go files importing rpc/pb/moe (excludes rpc/pb itself).
func RuntimeMoePbImportFileCount() int {
	n := 0
	roots := []string{"internal", "pkg", "cmd"}
	for _, root := range roots {
		n += countMoeImports(root)
	}
	return n
}

// RpcMoePbRetiredPercent is 100 when no runtime code imports rpc/pb/moe.
func RpcMoePbRetiredPercent() int {
	if RuntimeMoePbImportFileCount() == 0 {
		return 100
	}
	return 0
}

func countMoeImports(root string) int {
	n := 0
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}
		if !strings.HasSuffix(path, ".go") {
			return nil
		}
		b, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}
		if moePbImportRE.Match(b) {
			n++
		}
		return nil
	})
	return n
}
