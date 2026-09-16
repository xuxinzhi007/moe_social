//go:build !cgo

package utils

import "testing"

// TestDBTestsRequireCGO 是只在 CGO_ENABLED=0 时才编译进来的哨兵。
//
// 本仓所有需要真实数据库的用例都跑在 gorm.io/driver/sqlite 上，而该驱动依赖 cgo。
// CGO_ENABLED=0 时 gorm.Open 直接返回错误，各处 helper 一律 t.Skip —— 于是 `go test ./...`
// 报 ok，实际什么都没验证。实测后果：internal/biz/admin 与 pkg/achievement 各有一条失败用例
// 被长期跳过，pkg/moe/toolaudit 的数量阈值断言在注册表缩减后一直红着也没人看见。
//
// t.Skip 本身没错（没有 C 工具链的机器确实跑不了），错的是没人知道自己正在跳过，
// 所以这里用编译标签把「静默通过」换成「响亮失败」，并在信息里给出正确命令。
func TestDBTestsRequireCGO(t *testing.T) {
	t.Fatal("CGO_ENABLED=0：gorm 的 sqlite 驱动不可用，全仓 DB 用例会被静默 t.Skip，测试等于没跑。请改用 `make test`，或 `CGO_ENABLED=1 go test ./...`")
}
