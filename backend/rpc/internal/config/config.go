package config

import "github.com/zeromicro/go-zero/zrpc"

type Config struct {
	zrpc.RpcServerConf
	// HandDrawRequireModeration 为 true 时，含手绘的帖子创建后为 pending，需在库或管理端改为 ok
	HandDrawRequireModeration bool `json:",optional"`
}
