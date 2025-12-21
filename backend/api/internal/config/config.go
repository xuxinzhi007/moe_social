package config

import (
	"github.com/zeromicro/go-zero/rest"
	"github.com/zeromicro/go-zero/zrpc"
)

type Config struct {
	rest.RestConf
	// RPC服务配置
	SuperRpc zrpc.RpcClientConf `json:"SuperRpc"`
}
