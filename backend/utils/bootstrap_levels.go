package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

// BootstrapLevelData 仅在等级/签到奖励配置缺失时写入默认数据（源自 scripts/init_level_data.go）。
func BootstrapLevelData(db *gorm.DB) (levelConfigsCreated, checkInRewardsCreated int32, err error) {
	if db == nil {
		return 0, 0, nil
	}

	levelConfigs := []model.LevelConfig{
		{Level: 1, Title: "萌新菜鸟", MinExp: 0, MaxExp: 100, Privileges: `{"daily_post_limit": 5, "daily_comment_limit": 20}`, BadgeUrl: "/badges/level1.png"},
		{Level: 2, Title: "活跃新手", MinExp: 100, MaxExp: 500, Privileges: `{"daily_post_limit": 10, "daily_comment_limit": 50}`, BadgeUrl: "/badges/level2.png"},
		{Level: 3, Title: "社区中坚", MinExp: 500, MaxExp: 2000, Privileges: `{"daily_post_limit": 20, "daily_comment_limit": 100, "can_use_premium_emoji": true}`, BadgeUrl: "/badges/level3.png"},
		{Level: 4, Title: "资深达人", MinExp: 2000, MaxExp: 5000, Privileges: `{"daily_post_limit": 50, "daily_comment_limit": 200, "can_use_premium_emoji": true, "storage_quota_gb": 2}`, BadgeUrl: "/badges/level4.png"},
		{Level: 5, Title: "社区大师", MinExp: 5000, MaxExp: 999999, Privileges: `{"daily_post_limit": 100, "daily_comment_limit": 500, "can_use_premium_emoji": true, "storage_quota_gb": 5, "exclusive_features": ["priority_support", "exclusive_frames"]}`, BadgeUrl: "/badges/level5.png"},
	}
	for _, cfg := range levelConfigs {
		var existing model.LevelConfig
		if err := db.Where("level = ?", cfg.Level).First(&existing).Error; err != nil {
			if err := db.Create(&cfg).Error; err != nil {
				return levelConfigsCreated, checkInRewardsCreated, err
			}
			levelConfigsCreated++
		}
	}

	rewards := []model.CheckInReward{
		{ConsecutiveDays: 1, ExpReward: 0, ExtraReward: `{}`},
		{ConsecutiveDays: 3, ExpReward: 5, ExtraReward: `{}`},
		{ConsecutiveDays: 7, ExpReward: 20, ExtraReward: `{}`},
		{ConsecutiveDays: 15, ExpReward: 50, ExtraReward: `{}`},
		{ConsecutiveDays: 30, ExpReward: 100, ExtraReward: `{}`},
	}
	for _, reward := range rewards {
		var existing model.CheckInReward
		if err := db.Where("consecutive_days = ?", reward.ConsecutiveDays).First(&existing).Error; err != nil {
			if err := db.Create(&reward).Error; err != nil {
				return levelConfigsCreated, checkInRewardsCreated, err
			}
			checkInRewardsCreated++
		}
	}

	return levelConfigsCreated, checkInRewardsCreated, nil
}
