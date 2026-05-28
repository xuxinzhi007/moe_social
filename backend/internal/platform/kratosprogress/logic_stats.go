package kratosprogress

import (
	"os"
	"path/filepath"
	"strings"
)

// LegacyLogicBaseline P3 启动时 logic 文件数（用于 retired_pct）。
const LegacyLogicBaseline = 273

// LegacyLogicFileCount 当前 api/internal/logic 下 .go 文件数。
func LegacyLogicFileCount() int {
	root := filepath.Join("api", "internal", "logic")
	n := 0
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}
		if strings.HasSuffix(path, ".go") {
			n++
		}
		return nil
	})
	return n
}

// LegacyLogicRetiredPercent 已退役 logic 占比（0～100）。
func LegacyLogicRetiredPercent() int {
	if LegacyLogicBaseline <= 0 {
		return 0
	}
	left := LegacyLogicFileCount()
	if left >= LegacyLogicBaseline {
		return 0
	}
	p := (LegacyLogicBaseline - left) * 100 / LegacyLogicBaseline
	if p > 100 {
		return 100
	}
	return p
}
