package svc

import (
	"backend/api/internal/config"
	"backend/api/internal/moeadmingw"
	moepb "backend/api/moe/v1"
	moeadmin "backend/internal/service/moe"
	"backend/internal/platform/moewiring"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config         config.Config
	SuperRpcClient super.SuperClient
	MoeAdmin       *moeadmin.AdminService
	MoeGRPC        moepb.MoeAdminClient
	MoeGW          *moeadmingw.Gateway
	ModelCache     *utils.ModelCache
}

func NewServiceContext(c config.Config) *ServiceContext {
	rpcClient := zrpc.MustNewClient(c.SuperRpc)
	conn := rpcClient.Conn()
	superClient := super.NewSuperClient(conn)

	var moeGRPC moepb.MoeAdminClient
	if moewiring.UseMoeGRPCEnabled() {
		moeGRPC = moewiring.NewMoeGRPCAdminClient(conn)
	}

	return &ServiceContext{
		Config:         c,
		SuperRpcClient: superClient,
		MoeGRPC:        moeGRPC,
		MoeGW:          moeadmingw.NewConfigured(nil, moeGRPC, superClient),
		ModelCache:     utils.NewModelCache(),
	}
}
