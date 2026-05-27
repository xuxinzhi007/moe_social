package svc

import (
	"backend/api/internal/config"
	"backend/api/internal/moeadmingw"
	"backend/api/internal/usergw"
	"backend/api/internal/vipadmingw"
	moepb "backend/api/moe/v1"
	moeadmin "backend/internal/service/moe"
	userapp "backend/internal/service/user"
	vipadmin "backend/internal/service/vip"
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
	UserApp        *userapp.AppService
	UserGW         *usergw.Gateway
	VipAdmin       *vipadmin.AdminService
	VipGW          *vipadmingw.Gateway
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
		UserGW:         usergw.New(nil, superClient),
		VipGW:          vipadmingw.New(nil, superClient),
		ModelCache:     utils.NewModelCache(),
	}
}
