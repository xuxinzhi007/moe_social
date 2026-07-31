package adminbiz

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// AdminStore 管理端持久化（P4-D；默认由 internal/data/admin 实现）。
type AdminStore interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) AdminStore

	FindAdminAccountByUsername(ctx context.Context, username string) (model.AdminAccount, error)
	UpdateAdminLastLoginAt(ctx context.Context, accountID uint, at time.Time) error

	CountLandingFeedback(ctx context.Context) (int64, error)
	CountUsers(ctx context.Context) (int64, error)
	GetUserByID(ctx context.Context, userID uint) (model.User, error)
	CountUnlockedAchievements(ctx context.Context, userID uint) (int64, error)
	CountAiAgents(ctx context.Context, userID uint) (int64, error)
	GetUserLevel(ctx context.Context, userID uint) (model.UserLevel, error)
	GetLevelConfigByLevel(ctx context.Context, level int) (model.LevelConfig, error)

	ListUsers(ctx context.Context, keyword string, offset, limit int) ([]model.User, int64, error)
	UpdateUserFields(ctx context.Context, userID uint, updates map[string]interface{}) error
	ReloadUser(ctx context.Context, userID uint) (model.User, error)

	ListMenus(ctx context.Context) ([]model.AdminMenu, error)
	FindMenuByKey(ctx context.Context, key string) (model.AdminMenu, error)
	CreateMenu(ctx context.Context, row *model.AdminMenu) error
	SaveMenu(ctx context.Context, row *model.AdminMenu) error
	DeleteMenuByKey(ctx context.Context, key string) error

	ListAnnouncements(ctx context.Context, keyword, status string, offset, limit int) ([]model.AdminAnnouncement, int64, error)
	GetAnnouncementByID(ctx context.Context, id uint64) (model.AdminAnnouncement, error)
	CreateAnnouncement(ctx context.Context, row *model.AdminAnnouncement) error
	SaveAnnouncement(ctx context.Context, row *model.AdminAnnouncement) error
	DeleteAnnouncement(ctx context.Context, id uint64) error

	GetAppReleaseByPlatform(ctx context.Context, platform string) (model.AppRelease, error)
	CreateAppRelease(ctx context.Context, row *model.AppRelease) error
	SaveAppRelease(ctx context.Context, row *model.AppRelease) error

	ListAuditLogs(ctx context.Context, action, resource string, adminID uint64, offset, limit int) ([]model.AdminAuditLog, int64, error)

	CountModel(ctx context.Context, model any) (int64, error)
	CountUnlockedProgressRecords(ctx context.Context) (int64, error)
	CountCheckInsBetween(ctx context.Context, start, end time.Time) (int64, error)
	ModelTableName(model any) string
}

func dbFromStore(ctx context.Context, st AdminStore) *gorm.DB {
	if st == nil {
		return nil
	}
	if ctx != nil {
		return st.WithContext(ctx).Raw()
	}
	return st.Raw()
}
