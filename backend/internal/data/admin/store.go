package admindata

import (
	"context"
	"strings"
	"time"

	adminbiz "backend/internal/biz/admin"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.AdminStore（P4-D Lane F-admin）。
func NewStore(db *gorm.DB) adminbiz.AdminStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) adminbiz.AdminStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) FindAdminAccountByUsername(ctx context.Context, username string) (model.AdminAccount, error) {
	var acc model.AdminAccount
	err := s.db.WithContext(ctx).Where("username = ?", username).First(&acc).Error
	return acc, err
}

func (s *store) UpdateAdminLastLoginAt(ctx context.Context, accountID uint, at time.Time) error {
	return s.db.WithContext(ctx).Model(&model.AdminAccount{}).Where("id = ?", accountID).
		Update("last_login_at", at).Error
}

func (s *store) CountLandingFeedback(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.LandingFeedback{}).Count(&n).Error
	return n, err
}

func (s *store) CountUsers(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.User{}).Count(&n).Error
	return n, err
}

func (s *store) GetUserByID(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) CountUnlockedAchievements(ctx context.Context, userID uint) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.UserAchievementProgress{}).
		Where("user_id = ? AND unlocked_at IS NOT NULL", userID).Count(&n).Error
	return n, err
}

func (s *store) CountAiAgents(ctx context.Context, userID uint) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.AiUserConfig{}).Where("user_id = ?", userID).Count(&n).Error
	return n, err
}

func (s *store) GetUserLevel(ctx context.Context, userID uint) (model.UserLevel, error) {
	var row model.UserLevel
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&row).Error
	return row, err
}

func (s *store) GetLevelConfigByLevel(ctx context.Context, level int) (model.LevelConfig, error) {
	var row model.LevelConfig
	err := s.db.WithContext(ctx).Where("level = ?", level).First(&row).Error
	return row, err
}

func (s *store) ListUsers(ctx context.Context, keyword string, offset, limit int) ([]model.User, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.User{})
	if kw := strings.TrimSpace(keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("username LIKE ? OR email LIKE ? OR moe_no LIKE ?", like, like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var users []model.User
	err := q.Order("id ASC").Offset(offset).Limit(limit).Find(&users).Error
	return users, total, err
}

func (s *store) UpdateUserFields(ctx context.Context, userID uint, updates map[string]interface{}) error {
	return s.db.WithContext(ctx).Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error
}

func (s *store) ReloadUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *store) ListMenus(ctx context.Context) ([]model.AdminMenu, error) {
	var rows []model.AdminMenu
	err := s.db.WithContext(ctx).Order("sort_order ASC, id ASC").Find(&rows).Error
	return rows, err
}

func (s *store) FindMenuByKey(ctx context.Context, key string) (model.AdminMenu, error) {
	var row model.AdminMenu
	err := s.db.WithContext(ctx).Where("`key` = ?", key).First(&row).Error
	return row, err
}

func (s *store) CreateMenu(ctx context.Context, row *model.AdminMenu) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) SaveMenu(ctx context.Context, row *model.AdminMenu) error {
	return s.db.WithContext(ctx).Save(row).Error
}

func (s *store) DeleteMenuByKey(ctx context.Context, key string) error {
	return s.db.WithContext(ctx).Where("`key` = ?", key).Delete(&model.AdminMenu{}).Error
}

func (s *store) ListAnnouncements(ctx context.Context, keyword, status string, offset, limit int) ([]model.AdminAnnouncement, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.AdminAnnouncement{})
	if kw := strings.TrimSpace(keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("title LIKE ? OR content LIKE ?", like, like)
	}
	if st := strings.TrimSpace(status); st != "" {
		q = q.Where("status = ?", st)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.AdminAnnouncement
	err := q.Order("id DESC").Offset(offset).Limit(limit).Find(&rows).Error
	return rows, total, err
}

func (s *store) GetAnnouncementByID(ctx context.Context, id uint64) (model.AdminAnnouncement, error) {
	var row model.AdminAnnouncement
	err := s.db.WithContext(ctx).First(&row, id).Error
	return row, err
}

func (s *store) CreateAnnouncement(ctx context.Context, row *model.AdminAnnouncement) error {
	return s.db.WithContext(ctx).Create(row).Error
}

func (s *store) SaveAnnouncement(ctx context.Context, row *model.AdminAnnouncement) error {
	return s.db.WithContext(ctx).Save(row).Error
}

func (s *store) DeleteAnnouncement(ctx context.Context, id uint64) error {
	return s.db.WithContext(ctx).Delete(&model.AdminAnnouncement{}, id).Error
}

func (s *store) CountModel(ctx context.Context, model any) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(model).Count(&n).Error
	return n, err
}

func (s *store) CountUnlockedProgressRecords(ctx context.Context) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.UserAchievementProgress{}).
		Where("unlocked_at IS NOT NULL").Count(&n).Error
	return n, err
}

func (s *store) CountCheckInsBetween(ctx context.Context, start, end time.Time) (int64, error) {
	var n int64
	err := s.db.WithContext(ctx).Model(&model.UserCheckIn{}).
		Where("check_in_date >= ? AND check_in_date < ?", start, end).Count(&n).Error
	return n, err
}

func (s *store) ModelTableName(model any) string {
	if s.db == nil || model == nil {
		return ""
	}
	stmt := &gorm.Statement{DB: s.db}
	if err := stmt.Parse(model); err != nil {
		return ""
	}
	return stmt.Table
}

func (s *store) ListAuditLogs(ctx context.Context, action, resource string, adminID uint64, offset, limit int) ([]model.AdminAuditLog, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.AdminAuditLog{})
	if action = strings.TrimSpace(action); action != "" {
		q = q.Where("action = ?", action)
	}
	if resource = strings.TrimSpace(resource); resource != "" {
		q = q.Where("resource = ?", resource)
	}
	if adminID > 0 {
		q = q.Where("admin_id = ?", adminID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.AdminAuditLog
	err := q.Order("id DESC").Offset(offset).Limit(limit).Find(&rows).Error
	return rows, total, err
}
