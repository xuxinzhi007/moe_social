package kratosprogress

import (
	"os"
	"path/filepath"
	"strings"

	"backend/internal/platform/moewiring"
)

// RPCLegacyLogicBaseline P5 启动时 rpc/internal/logic 文件数（Super goctl 层）。
const RPCLegacyLogicBaseline = 209

// RPCLegacyLogicFileCount 当前 rpc/internal/logic 下 .go 文件数。
func RPCLegacyLogicFileCount() int {
	root := filepath.Join("rpc", "internal", "logic")
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

// RPCLegacyLogicRetiredPercent Super logic 清库进度（0～100）。
func RPCLegacyLogicRetiredPercent() int {
	left := RPCLegacyLogicFileCount()
	if left == 0 {
		return 100
	}
	if RPCLegacyLogicBaseline <= 0 {
		return 0
	}
	if left >= RPCLegacyLogicBaseline {
		return 0
	}
	p := (RPCLegacyLogicBaseline - left) * 100 / RPCLegacyLogicBaseline
	if p > 100 {
		return 100
	}
	return p
}

// P5SuperRuntimePercent P5-A：Super 运行时退役（不注册 gRPC、API 不走 zrpc 回环）。
func P5SuperRuntimePercent() int {
	return boolPercent(moewiring.SuperGrpcRetired())
}
