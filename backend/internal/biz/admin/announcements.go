package adminbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"

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

func announcementToProto(row model.AdminAnnouncement) *super.AdminAnnouncementItem {
	item := &super.AdminAnnouncementItem{
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

func adminAuditLogToProto(row model.AdminAuditLog) *super.AdminAuditLogItem {
	return &super.AdminAuditLogItem{
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
func ListAnnouncements(ctx context.Context, db *gorm.DB, p AnnouncementPage) ([]*super.AdminAnnouncementItem, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(p.Page, p.PageSize)
	q := db.WithContext(ctx).Model(&model.AdminAnnouncement{})
	if kw := strings.TrimSpace(p.Keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("title LIKE ? OR content LIKE ?", like, like)
	}
	if st := strings.TrimSpace(p.Status); st != "" {
		q = q.Where("status = ?", st)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.AdminAnnouncement
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	items := make([]*super.AdminAnnouncementItem, len(rows))
	for i, row := range rows {
		items[i] = announcementToProto(row)
	}
	return items, int32(total), nil
}

// GetAnnouncement 公告详情。
func GetAnnouncement(ctx context.Context, db *gorm.DB, idRaw string) (*super.AdminAnnouncementItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(idRaw), 10, 64)
	if err != nil || id == 0 {
		return nil, ErrInvalidAnnouncementID
	}
	var row model.AdminAnnouncement
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
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
func ListAuditLogs(ctx context.Context, db *gorm.DB, f AuditLogFilter) ([]*super.AdminAuditLogItem, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(f.Page, f.PageSize)
	q := db.WithContext(ctx).Model(&model.AdminAuditLog{})
	if action := strings.TrimSpace(f.Action); action != "" {
		q = q.Where("action = ?", action)
	}
	if resource := strings.TrimSpace(f.Resource); resource != "" {
		q = q.Where("resource = ?", resource)
	}
	if adminID := strings.TrimSpace(f.AdminID); adminID != "" {
		id, err := strconv.ParseUint(adminID, 10, 64)
		if err != nil {
			return nil, 0, ErrInvalidArgument
		}
		q = q.Where("admin_id = ?", id)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.AdminAuditLog
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	items := make([]*super.AdminAuditLogItem, len(rows))
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
