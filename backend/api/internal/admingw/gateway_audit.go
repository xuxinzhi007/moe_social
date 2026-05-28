package admingw

import (
	"context"

	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) RecordAdminAuditLog(ctx context.Context, in *moe.RecordAdminAuditLogReq, opts ...grpc.CallOption) (*moe.RecordAdminAuditLogResp, error) {
	if g != nil && g.local != nil {
		return g.local.RecordAuditLog(ctx, in)
	}
	if g == nil || g.super == nil {
		return &moe.RecordAdminAuditLogResp{}, nil
	}
	return g.super.RecordAdminAuditLog(ctx, in, opts...)
}
