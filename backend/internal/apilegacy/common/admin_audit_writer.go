package common

import (
	"context"
	"strings"

	"backend/internal/platform/svc"
	"backend/rpc/pb/moe"

	"backend/internal/platform/moelog"
)

// TryRecordAdminAudit 在管理写操作成功后异步写入审计日志（失败不影响主流程）。
func TryRecordAdminAudit(ctx context.Context, svcCtx *svc.ServiceContext, action, resource, resourceID, detail string) {
	if svcCtx == nil || svcCtx.AdminGW == nil {
		return
	}
	actor, ok := AdminActorFromContext(ctx)
	if !ok {
		return
	}
	action = strings.TrimSpace(action)
	resource = strings.TrimSpace(resource)
	if action == "" || resource == "" {
		return
	}

	req := &moe.RecordAdminAuditLogReq{
		AdminId:    uint64(actor.AdminID),
		AdminName:  actor.AdminName,
		Action:     action,
		Resource:   resource,
		ResourceId: strings.TrimSpace(resourceID),
		Detail:     strings.TrimSpace(detail),
		Ip:         actor.IP,
	}
	go func() {
		if _, err := svcCtx.AdminGW.RecordAdminAuditLog(context.Background(), req); err != nil {
			moelog.Error("record admin audit", "action", action, "resource", resource, "err", err)
		}
	}()
}
