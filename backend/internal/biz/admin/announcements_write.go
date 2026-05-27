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

var ErrEmptyAnnouncementTitle = errors.New("empty announcement title")

// CreateAnnouncement 创建草稿公告。
func CreateAnnouncement(ctx context.Context, db *gorm.DB, title, content, createdByRaw string) (*super.AdminAnnouncementItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	title = strings.TrimSpace(title)
	if title == "" {
		return nil, ErrEmptyAnnouncementTitle
	}
	createdBy, _ := strconv.ParseUint(strings.TrimSpace(createdByRaw), 10, 64)
	row := model.AdminAnnouncement{
		Title:     title,
		Content:   strings.TrimSpace(content),
		Status:    model.AnnouncementStatusDraft,
		CreatedBy: uint(createdBy),
	}
	if err := db.WithContext(ctx).Create(&row).Error; err != nil {
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// UpdateAnnouncementInput 更新公告参数。
type UpdateAnnouncementInput struct {
	AnnouncementID string
	Title          string
	Content        string
	UpdateTitle    bool
	UpdateContent  bool
}

// UpdateAnnouncement 更新公告。
func UpdateAnnouncement(ctx context.Context, db *gorm.DB, in UpdateAnnouncementInput) (*super.AdminAnnouncementItem, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(in.AnnouncementID), 10, 64)
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

	updates := false
	if in.UpdateTitle {
		title := strings.TrimSpace(in.Title)
		if title == "" {
			return nil, ErrEmptyAnnouncementTitle
		}
		row.Title = title
		updates = true
	}
	if in.UpdateContent {
		row.Content = strings.TrimSpace(in.Content)
		updates = true
	}
	if !updates {
		if reqTitle := strings.TrimSpace(in.Title); reqTitle != "" {
			row.Title = reqTitle
			updates = true
		}
		if in.Content != "" {
			row.Content = strings.TrimSpace(in.Content)
			updates = true
		}
	}
	if err := db.WithContext(ctx).Save(&row).Error; err != nil {
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// PublishAnnouncement 发布公告。
func PublishAnnouncement(ctx context.Context, db *gorm.DB, idRaw string) (*super.AdminAnnouncementItem, error) {
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
	now := time.Now()
	row.Status = model.AnnouncementStatusPublished
	row.PublishedAt = &now
	if err := db.WithContext(ctx).Save(&row).Error; err != nil {
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// DeleteAnnouncement 删除公告。
func DeleteAnnouncement(ctx context.Context, db *gorm.DB, idRaw string) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(idRaw), 10, 64)
	if err != nil || id == 0 {
		return ErrInvalidAnnouncementID
	}
	if err := db.WithContext(ctx).Delete(&model.AdminAnnouncement{}, id).Error; err != nil {
		return err
	}
	return nil
}
