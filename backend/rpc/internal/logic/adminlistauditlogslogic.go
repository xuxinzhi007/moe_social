package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAuditLogsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAuditLogsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAuditLogsLogic {
	return &AdminListAuditLogsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAuditLogsLogic) AdminListAuditLogs(in *super.AdminListAuditLogsReq) (*super.AdminListAuditLogsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.AdminAuditLog{})
	if action := strings.TrimSpace(in.GetAction()); action != "" {
		q = q.Where("action = ?", action)
	}
	if resource := strings.TrimSpace(in.GetResource()); resource != "" {
		q = q.Where("resource = ?", resource)
	}
	if adminID := strings.TrimSpace(in.GetAdminId()); adminID != "" {
		id, err := strconv.ParseUint(adminID, 10, 64)
		if err != nil {
			return nil, errorx.InvalidArgument("管理员 ID 无效")
		}
		q = q.Where("admin_id = ?", id)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count audit logs: %v", err)
		return nil, errorx.Internal("查询审计日志失败")
	}
	var rows []model.AdminAuditLog
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list audit logs: %v", err)
		return nil, errorx.Internal("查询审计日志失败")
	}
	items := make([]*super.AdminAuditLogItem, len(rows))
	for i, row := range rows {
		items[i] = adminAuditLogToProto(row)
	}
	return &super.AdminListAuditLogsResp{Items: items, Total: int32(total)}, nil
}
