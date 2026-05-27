package moewiring

import (
	moepb "backend/api/moe/v1"

	"google.golang.org/grpc"
)

// NewMoeGRPCAdminClient 复用 Super RPC 连接，调用同端口的 moe.v1.MoeAdmin。
func NewMoeGRPCAdminClient(conn grpc.ClientConnInterface) moepb.MoeAdminClient {
	if conn == nil {
		return nil
	}
	return moepb.NewMoeAdminClient(conn)
}
