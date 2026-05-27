package adminbiz

import (
	"context"
	"time"

	"backend/model"
	"backend/pkg/calendar"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

// GrowthStats 管理台成长统计。
func GrowthStats(ctx context.Context, db *gorm.DB) (*super.AdminGrowthStats, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	stats := &super.AdminGrowthStats{}

	count := func(model any, dest *int32) error {
		var n int64
		if err := db.WithContext(ctx).Model(model).Count(&n).Error; err != nil {
			return err
		}
		*dest = int32(n)
		return nil
	}

	if err := count(&model.AchievementDefinition{}, &stats.AchievementDefinitions); err != nil {
		return nil, err
	}
	var unlocked int64
	if err := db.WithContext(ctx).Model(&model.UserAchievementProgress{}).Where("unlocked_at IS NOT NULL").Count(&unlocked).Error; err != nil {
		return nil, err
	}
	stats.UnlockedProgressRecords = int32(unlocked)

	if err := count(&model.LevelConfig{}, &stats.LevelConfigs); err != nil {
		return nil, err
	}
	if err := count(&model.CheckInReward{}, &stats.CheckInRewards); err != nil {
		return nil, err
	}
	if err := count(&model.UserLevel{}, &stats.UserLevels); err != nil {
		return nil, err
	}
	if err := count(&model.UserCheckIn{}, &stats.TotalCheckIns); err != nil {
		return nil, err
	}

	now := time.Now()
	dayStart, dayEnd := calendar.ShanghaiDayBounds(now)
	var todayCount int64
	if err := db.WithContext(ctx).Model(&model.UserCheckIn{}).
		Where("check_in_date >= ? AND check_in_date < ?", dayStart, dayEnd).
		Count(&todayCount).Error; err != nil {
		return nil, err
	}
	stats.CheckInsToday = int32(todayCount)
	return stats, nil
}

// SchemaCatalog 数据目录与行数统计。
func SchemaCatalog(ctx context.Context, db *gorm.DB) (*super.AdminGetSchemaCatalogResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	catalog := utils.AdminSchemaCatalog()
	items := make([]*super.AdminSchemaTableItem, 0, len(catalog))
	summary := &super.AdminSchemaCatalogSummary{TotalTables: int32(len(catalog))}

	for _, entry := range catalog {
		tableName := schemaTableName(db, entry.Model)
		rowCount := countSchemaRows(db.WithContext(ctx), entry.Model)
		if rowCount >= 0 {
			summary.TotalRows += rowCount
		}
		coverage := utils.AdminSchemaCoverage(entry.Capabilities)
		switch coverage {
		case "full":
			summary.ManagedFull++
		case "partial", "readonly":
			summary.ManagedPartial++
		default:
			summary.Unmanaged++
		}
		items = append(items, &super.AdminSchemaTableItem{
			Key:          entry.Key,
			TableName:    tableName,
			Label:        entry.Label,
			Domain:       entry.Domain,
			Coverage:     coverage,
			Capabilities: entry.Capabilities,
			AdminRoute:   entry.AdminRoute,
			BootstrapKey: entry.BootstrapKey,
			RowCount:     rowCount,
			Note:         entry.Note,
		})
	}
	return &super.AdminGetSchemaCatalogResp{Summary: summary, Items: items}, nil
}

func schemaTableName(db *gorm.DB, model interface{}) string {
	if db == nil || model == nil {
		return ""
	}
	stmt := &gorm.Statement{DB: db}
	if err := stmt.Parse(model); err != nil {
		return ""
	}
	return stmt.Table
}

func countSchemaRows(db *gorm.DB, model interface{}) int64 {
	if db == nil || model == nil {
		return -1
	}
	var n int64
	if err := db.Model(model).Count(&n).Error; err != nil {
		return -1
	}
	return n
}

// RuntimeConfigView 读取运行时配置视图。
func RuntimeConfigView() (utils.RuntimeConfigView, error) {
	return utils.ReadRuntimeConfig()
}
