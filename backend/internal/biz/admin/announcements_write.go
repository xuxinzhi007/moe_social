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

var ErrEmptyAnnouncementTitle = errors.New("empty announcement title")

// CreateAnnouncement 创建草稿公告。
func CreateAnnouncement(ctx context.Context, store AdminStore, title, content, createdByRaw string) (*moe.AdminAnnouncementItem, error) {
	if store == nil {
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
	if err := store.CreateAnnouncement(ctx, &row); err != nil {
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
func UpdateAnnouncement(ctx context.Context, store AdminStore, in UpdateAnnouncementInput) (*moe.AdminAnnouncementItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(in.AnnouncementID), 10, 64)
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
	if err := store.SaveAnnouncement(ctx, &row); err != nil {
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// PublishAnnouncement 发布公告。
func PublishAnnouncement(ctx context.Context, store AdminStore, idRaw string) (*moe.AdminAnnouncementItem, error) {
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
	now := time.Now()
	row.Status = model.AnnouncementStatusPublished
	row.PublishedAt = &now
	if err := store.SaveAnnouncement(ctx, &row); err != nil {
		return nil, err
	}
	item := announcementToProto(row)
	return item, nil
}

// DeleteAnnouncement 删除公告。
func DeleteAnnouncement(ctx context.Context, store AdminStore, idRaw string) error {
	if store == nil {
		return gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(idRaw), 10, 64)
	if err != nil || id == 0 {
		return ErrInvalidAnnouncementID
	}
	return store.DeleteAnnouncement(ctx, id)
}
