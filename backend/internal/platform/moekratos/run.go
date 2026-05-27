// Package moekratos 纯 Kratos 试点：与 go-zero 并行，固定开发端口 19031/19032。
package moekratos

import (
	"backend/utils"
)

// Options 试点启动参数。
type Options struct {
	GRPCAddr string
	HTTPAddr string
	SuperRPC string // 可选；空则读 config moe.pilot.super_rpc_endpoint
	Migrate  utils.MigrateOptions
}

// Run 启动纯 Kratos 试点（Wire 装配 + moe.conf.v1.Bootstrap）。
func Run(opts Options) error {
	app, err := InitializeApp(opts)
	if err != nil {
		return err
	}
	app.logStartup(app.GRPCAddr, app.HTTPAddr, app.SuperRPC)
	return app.Kratos.Run()
}
