package admingw

import (
	"backend/api/internal/gwutil"
	"context"

	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) RecordAdminAuditLog(ctx context.Context, in *moe.RecordAdminAuditLogReq, opts ...grpc.CallOption) (*moe.RecordAdminAuditLogResp, error) {
	if g != nil && g.local != nil {
		return g.local.RecordAuditLog(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
