package svc

import (
	"backend/api/internal/config"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config         config.Config
	SuperRpcClient rpc.SuperClient
}

func NewServiceContext(c config.Config) *ServiceContext {
	// 创建RPC客户端
	rpcClient := zrpc.MustNewClient(c.SuperRpc)

	return &ServiceContext{
		Config:         c,
		SuperRpcClient: rpc.NewSuperClient(rpcClient.Conn()),
	}
}
