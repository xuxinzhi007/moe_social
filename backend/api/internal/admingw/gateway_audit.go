package admingw

import (
	"context"

	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

func (g *Gateway) RecordAdminAuditLog(ctx context.Context, in *super.RecordAdminAuditLogReq, opts ...grpc.CallOption) (*super.RecordAdminAuditLogResp, error) {
	if g != nil && g.local != nil {
		return g.local.RecordAuditLog(ctx, in)
	}
	if g == nil || g.super == nil {
		return &super.RecordAdminAuditLogResp{}, nil
	}
	return g.super.RecordAdminAuditLog(ctx, in, opts...)
}
