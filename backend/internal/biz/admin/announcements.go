package adminbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

var (
	ErrInvalidAnnouncementID = errors.New("invalid announcement id")
	ErrAnnouncementNotFound  = errors.New("announcement not found")
)

// AnnouncementPage 公告分页。
type AnnouncementPage struct {
	Page     int32
	PageSize int32
	Keyword  string
	Status   string
}

func adminPageParams(page, pageSize int32) (int32, int32) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}
	return page, pageSize
}

func announcementToProto(row model.AdminAnnouncement) *moe.AdminAnnouncementItem {
	item := &moe.AdminAnnouncementItem{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Title:     row.Title,
		Content:   row.Content,
		Status:    row.Status,
		CreatedBy: strconv.FormatUint(uint64(row.CreatedBy), 10),
		CreatedAt: row.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt: row.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
	if row.PublishedAt != nil {
		item.PublishedAt = row.PublishedAt.Format("2006-01-02 15:04:05")
	}
	return item
}

func adminAuditLogToProto(row model.AdminAuditLog) *moe.AdminAuditLogItem {
	return &moe.AdminAuditLogItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		AdminId:    strconv.FormatUint(uint64(row.AdminID), 10),
		AdminName:  row.AdminName,
		Action:     row.Action,
		Resource:   row.Resource,
		ResourceId: row.ResourceID,
		Detail:     row.Detail,
		Ip:         row.IP,
		CreatedAt:  row.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}

// ListAnnouncements 公告列表。
func ListAnnouncements(ctx context.Context, store AdminStore, p AnnouncementPage) ([]*moe.AdminAnnouncementItem, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(p.Page, p.PageSize)
	offset := int((page - 1) * pageSize)
	rows, total, err := store.ListAnnouncements(ctx, p.Keyword, p.Status, offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}
	items := make([]*moe.AdminAnnouncementItem, len(rows))
	for i, row := range rows {
		items[i] = announcementToProto(row)
	}
	return items, int32(total), nil
}

// GetAnnouncement 公告详情。
func GetAnnouncement(ctx context.Context, store AdminStore, idRaw string) (*moe.AdminAnnouncementItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(idRaw), 10, 64)
	if err != nil || id == 0 {
		return nil, ErrInvalidAnnouncementID
	}
	row, err := store.GetAnnouncementByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAnnouncementNotFound
		}
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// AuditLogFilter 审计日志筛选。
type AuditLogFilter struct {
	Page     int32
	PageSize int32
	Action   string
	Resource string
	AdminID  string
}

// ListAuditLogs 审计日志列表。
func ListAuditLogs(ctx context.Context, store AdminStore, f AuditLogFilter) ([]*moe.AdminAuditLogItem, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(f.Page, f.PageSize)
	var adminID uint64
	if adminIDRaw := strings.TrimSpace(f.AdminID); adminIDRaw != "" {
		id, err := strconv.ParseUint(adminIDRaw, 10, 64)
		if err != nil {
			return nil, 0, ErrInvalidArgument
		}
		adminID = id
	}
	offset := int((page - 1) * pageSize)
	rows, total, err := store.ListAuditLogs(ctx, f.Action, f.Resource, adminID, offset, int(pageSize))
	if err != nil {
		return nil, 0, err
	}
	items := make([]*moe.AdminAuditLogItem, len(rows))
	for i, row := range rows {
		items[i] = adminAuditLogToProto(row)
	}
	return items, int32(total), nil
}

// ErrInvalidArgument admin 参数无效。
var ErrInvalidArgument = errors.New("invalid argument")

// FormatOptionalTime 格式化可选时间（供其它 admin biz 使用）。
func FormatOptionalTime(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format("2006-01-02 15:04:05")
}
