package bootstrap

import (
	moepb "backend/api/moe/v1"
	"backend/internal/platform/moewiring"
	grpcserver "backend/internal/server/grpc"
	"backend/rpc/internal/svc"

	"google.golang.org/grpc"
)

// RegisterMoeGRPC 在同一 gRPC 端口注册 moe.v1.MoeAdmin（与 super.Super 并存）。
func RegisterMoeGRPC(grpcServer *grpc.Server, svcCtx *svc.ServiceContext) {
	if grpcServer == nil || svcCtx == nil || svcCtx.MoeAdmin == nil {
		return
	}
	if !moewiring.RegisterMoeGRPCEnabled() {
		return
	}
	moepb.RegisterMoeAdminServer(grpcServer, grpcserver.New(svcCtx.MoeAdmin))
}
