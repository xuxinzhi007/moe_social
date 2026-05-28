package adminbiz

import (
	"context"
	"time"

	"backend/model"
	"backend/pkg/calendar"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

// GrowthStats 管理台成长统计。
func GrowthStats(ctx context.Context, store AdminStore) (*moe.AdminGrowthStats, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	stats := &moe.AdminGrowthStats{}

	count := func(model any, dest *int32) error {
		n, err := store.CountModel(ctx, model)
		if err != nil {
			return err
		}
		*dest = int32(n)
		return nil
	}

	if err := count(&model.AchievementDefinition{}, &stats.AchievementDefinitions); err != nil {
		return nil, err
	}
	unlocked, err := store.CountUnlockedProgressRecords(ctx)
	if err != nil {
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
	todayCount, err := store.CountCheckInsBetween(ctx, dayStart, dayEnd)
	if err != nil {
		return nil, err
	}
	stats.CheckInsToday = int32(todayCount)
	return stats, nil
}

// SchemaCatalog 数据目录与行数统计。
func SchemaCatalog(ctx context.Context, store AdminStore) (*moe.AdminGetSchemaCatalogResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	catalog := utils.AdminSchemaCatalog()
	items := make([]*moe.AdminSchemaTableItem, 0, len(catalog))
	summary := &moe.AdminSchemaCatalogSummary{TotalTables: int32(len(catalog))}

	for _, entry := range catalog {
		tableName := store.ModelTableName(entry.Model)
		rowCount := countSchemaRows(ctx, store, entry.Model)
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
		items = append(items, &moe.AdminSchemaTableItem{
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
	return &moe.AdminGetSchemaCatalogResp{Summary: summary, Items: items}, nil
}

func countSchemaRows(ctx context.Context, store AdminStore, model any) int64 {
	if store == nil || model == nil {
		return -1
	}
	n, err := store.CountModel(ctx, model)
	if err != nil {
		return -1
	}
	return n
}

// RuntimeConfigView 读取运行时配置视图。
func RuntimeConfigView() (utils.RuntimeConfigView, error) {
	return utils.ReadRuntimeConfig()
}
