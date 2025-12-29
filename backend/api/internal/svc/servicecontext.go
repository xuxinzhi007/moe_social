package svc

import (
	"backend/api/internal/config"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config         config.Config
	SuperRpcClient super.SuperClient
}

func NewServiceContext(c config.Config) *ServiceContext {
	// 创建RPC客户端
	rpcClient := zrpc.MustNewClient(c.SuperRpc)

	return &ServiceContext{
		Config:         c,
		SuperRpcClient: super.NewSuperClient(rpcClient.Conn()),
	}
}
