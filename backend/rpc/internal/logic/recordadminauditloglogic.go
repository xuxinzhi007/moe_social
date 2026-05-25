package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

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
	err := utils.WriteAdminAuditLog(l.svcCtx.DB, utils.AdminAuditEntry{
		AdminID:    uint(in.GetAdminId()),
		AdminName:  in.GetAdminName(),
		Action:     in.GetAction(),
		Resource:   in.GetResource(),
		ResourceID: in.GetResourceId(),
		Detail:     in.GetDetail(),
		IP:         in.GetIp(),
	})
	if err != nil {
		l.Errorf("[admin] record audit log: %v", err)
	}
	return &super.RecordAdminAuditLogResp{}, nil
}
