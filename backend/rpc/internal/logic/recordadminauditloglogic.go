package logic

import (
	"context"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type RecordAdminAuditLogLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRecordAdminAuditLogLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RecordAdminAuditLogLogic {
	return &RecordAdminAuditLogLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *RecordAdminAuditLogLogic) RecordAdminAuditLog(in *super.RecordAdminAuditLogReq) (*super.RecordAdminAuditLogResp, error) {
	if in.GetAdminId() == 0 {
		return &super.RecordAdminAuditLogResp{}, nil
	}
	if err := adminbiz.RecordAuditLog(l.ctx, l.svcCtx.DB, in); err != nil {
		l.Errorf("[admin] record audit log: %v", err)
	}
	return &super.RecordAdminAuditLogResp{}, nil
}
