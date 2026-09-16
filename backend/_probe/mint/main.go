package main

import (
	"fmt"
	"os"

	"backend/utils"
)

// 真机复验用：给一个不存在的 uid 签发短期 JWT，避免往共享测试库写任何真实账号。
func main() {
	if err := utils.ConfigureJWT(os.Getenv("MOE_PROBE_SECRET"), 3600); err != nil {
		fmt.Fprintln(os.Stderr, "configure:", err)
		os.Exit(1)
	}
	tok, err := utils.GenerateToken(999999, "probe-user")
	if err != nil {
		fmt.Fprintln(os.Stderr, "generate:", err)
		os.Exit(1)
	}
	fmt.Print(tok)
}
