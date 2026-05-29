package admingw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	adminv1 "backend/api/admin/v1"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

func (g *Gateway) RecordAdminAuditLog(ctx context.Context, in *moe.RecordAdminAuditLogReq, opts ...grpc.CallOption) (*moe.RecordAdminAuditLogResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.RecordAuditLog(ctx, adminv1.RecordAdminAuditLogReqFromMoe(in))
		if err != nil {
			return nil, err
		}
		return adminv1.RecordAdminAuditLogRespToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
