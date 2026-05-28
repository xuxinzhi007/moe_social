package adminbiz

import (
	"context"

	"backend/rpc/pb/moe"
	"backend/utils"
)

// RecordAuditLog 写入管理端操作审计（失败时由调用方决定是否记录日志）。
func RecordAuditLog(ctx context.Context, store AdminStore, in *moe.RecordAdminAuditLogReq) error {
	db := dbFromStore(ctx, store)
	if db == nil || in == nil || in.GetAdminId() == 0 {
		return nil
	}
	_ = ctx
	return utils.WriteAdminAuditLog(db, utils.AdminAuditEntry{
		AdminID:    uint(in.GetAdminId()),
		AdminName:  in.GetAdminName(),
		Action:     in.GetAction(),
		Resource:   in.GetResource(),
		ResourceID: in.GetResourceId(),
		Detail:     in.GetDetail(),
		IP:         in.GetIp(),
	})
}
