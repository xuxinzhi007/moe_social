package utils

import (
	"errors"
	"fmt"

	"backend/model"

	"gorm.io/gorm"
)

// dedupeLifeItemsByName 在 life_items 建唯一索引（idx_life_items_name）之前合并同名重复行。
//
// 背景（config-hygiene-review-2026-09-08 §22.7 / 问题 17）：种子写入用
// OnConflict{DoNothing} 防重，但 Name 一直缺 uniqueIndex，冲突条件永不成立 ——
// 每次进程启动往 life_items 插入 6 条重复（实测 594 → 600）。修法是给 Name 加
// 唯一索引让 DoNothing 生效，但已被污染的库必须先清理，否则建索引直接失败。
//
// 归并规则：同名保留 ID 最小的一行；life_inventory 是唯一外键读者，先把挂在重复行
// 上的背包挪到保留行（同用户同道具的数量相加），再删重复行。全程一个事务且幂等：
// 无重复时零改动；重复已清后再次执行零改动。
func dedupeLifeItemsByName(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		// 全新库尚未建表：无从清理，直接放行（首次迁移由 AutoMigrate 建表）。
		if !tx.Migrator().HasTable(&model.LifeItem{}) || !tx.Migrator().HasTable(&model.LifeInventory{}) {
			return nil
		}

		var names []string
		if err := tx.Model(&model.LifeItem{}).
			Select("name").
			Group("name").
			Having("COUNT(*) > 1").
			Pluck("name", &names).Error; err != nil {
			return fmt.Errorf("查找重复道具名失败: %w", err)
		}
		for _, name := range names {
			var ids []uint
			if err := tx.Model(&model.LifeItem{}).
				Where("name = ?", name).
				Order("id ASC").
				Pluck("id", &ids).Error; err != nil {
				return fmt.Errorf("查询道具 %q 的行失败: %w", name, err)
			}
			if len(ids) < 2 {
				continue
			}
			canon, dups := ids[0], ids[1:]
			for _, dup := range dups {
				if err := mergeInventoryToCanon(tx, name, canon, dup); err != nil {
					return err
				}
			}
			if err := tx.Where("id IN ?", dups).Delete(&model.LifeItem{}).Error; err != nil {
				return fmt.Errorf("删除道具 %q 的重复行失败: %w", name, err)
			}
		}
		return nil
	})
}

// mergeInventoryToCanon 把挂在 dup 道具上的背包行归并到 canon：已有 canon 行则数量相加
// 并删旧行，否则把行改指 canon。逐行顺序处理，(user_id, item_id) 唯一索引在任何中间态
// 都不冲突 —— 同一用户即便在多个 dup 上都有行，第一个 dup 的行会先改指/累加到 canon，
// 后续 dup 的行都走「已有 canon 行」分支。
func mergeInventoryToCanon(tx *gorm.DB, name string, canon, dup uint) error {
	var rows []model.LifeInventory
	if err := tx.Where("item_id = ?", dup).Find(&rows).Error; err != nil {
		return fmt.Errorf("查询道具 %q 重复行 %d 的库存失败: %w", name, dup, err)
	}
	for _, row := range rows {
		var existing model.LifeInventory
		err := tx.Where("user_id = ? AND item_id = ?", row.UserID, canon).First(&existing).Error
		switch {
		case err == nil:
			if err := tx.Model(&existing).
				UpdateColumn("quantity", gorm.Expr("quantity + ?", row.Quantity)).Error; err != nil {
				return fmt.Errorf("累加库存失败: %w", err)
			}
			if err := tx.Delete(&row).Error; err != nil {
				return fmt.Errorf("删除旧库存行失败: %w", err)
			}
		case errors.Is(err, gorm.ErrRecordNotFound):
			if err := tx.Model(&row).Update("item_id", canon).Error; err != nil {
				return fmt.Errorf("库存改指失败: %w", err)
			}
		default:
			return fmt.Errorf("查询 canonical 库存失败: %w", err)
		}
	}
	return nil
}
