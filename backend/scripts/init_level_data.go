package scripts

import (
	"backend/model"
	"backend/utils"
	"log"
)

// InitLevelConfigs 初始化等级配置
func InitLevelConfigs() error {
	configs := []model.LevelConfig{
		{
			Level:      1,
			Title:      "萌新菜鸟",
			MinExp:     0,
			MaxExp:     100,
			Privileges: `{"daily_post_limit": 5, "daily_comment_limit": 20}`,
			BadgeUrl:   "/badges/level1.png",
		},
		{
			Level:      2,
			Title:      "活跃新手",
			MinExp:     100,
			MaxExp:     500,
			Privileges: `{"daily_post_limit": 10, "daily_comment_limit": 50}`,
			BadgeUrl:   "/badges/level2.png",
		},
		{
			Level:      3,
			Title:      "社区中坚",
			MinExp:     500,
			MaxExp:     2000,
			Privileges: `{"daily_post_limit": 20, "daily_comment_limit": 100, "can_use_premium_emoji": true}`,
			BadgeUrl:   "/badges/level3.png",
		},
		{
			Level:      4,
			Title:      "资深达人",
			MinExp:     2000,
			MaxExp:     5000,
			Privileges: `{"daily_post_limit": 50, "daily_comment_limit": 200, "can_use_premium_emoji": true, "storage_quota_gb": 2}`,
			BadgeUrl:   "/badges/level4.png",
		},
		{
			Level:      5,
			Title:      "社区大师",
			MinExp:     5000,
			MaxExp:     999999,
			Privileges: `{"daily_post_limit": 100, "daily_comment_limit": 500, "can_use_premium_emoji": true, "storage_quota_gb": 5, "exclusive_features": ["priority_support", "exclusive_frames"]}`,
			BadgeUrl:   "/badges/level5.png",
		},
	}

	db := utils.GetDB()
	for _, config := range configs {
		var existingConfig model.LevelConfig
		if err := db.Where("level = ?", config.Level).First(&existingConfig).Error; err != nil {
			// 不存在，创建新的
			if err := db.Create(&config).Error; err != nil {
				log.Printf("创建等级配置失败: %v", err)
				return err
			}
			log.Printf("创建等级配置: %s (Level %d)", config.Title, config.Level)
		}
	}
	return nil
}

// InitCheckInRewards 初始化签到奖励配置
func InitCheckInRewards() error {
	rewards := []model.CheckInReward{
		{ConsecutiveDays: 1, ExpReward: 0, ExtraReward: `{}`},     // 第1天基础签到无额外奖励
		{ConsecutiveDays: 3, ExpReward: 5, ExtraReward: `{}`},     // 连续3天+5经验
		{ConsecutiveDays: 7, ExpReward: 20, ExtraReward: `{}`},    // 连续7天+20经验
		{ConsecutiveDays: 15, ExpReward: 50, ExtraReward: `{}`},   // 连续15天+50经验
		{ConsecutiveDays: 30, ExpReward: 100, ExtraReward: `{}`},  // 连续30天+100经验
	}

	db := utils.GetDB()
	for _, reward := range rewards {
		var existingReward model.CheckInReward
		if err := db.Where("consecutive_days = ?", reward.ConsecutiveDays).First(&existingReward).Error; err != nil {
			// 不存在，创建新的
			if err := db.Create(&reward).Error; err != nil {
				log.Printf("创建签到奖励配置失败: %v", err)
				return err
			}
			log.Printf("创建签到奖励配置: 连续%d天 +%d经验", reward.ConsecutiveDays, reward.ExpReward)
		}
	}
	return nil
}

// InitAllLevelData 初始化所有等级相关数据
func InitAllLevelData() error {
	if err := InitLevelConfigs(); err != nil {
		return err
	}
	if err := InitCheckInRewards(); err != nil {
		return err
	}
	log.Println("等级系统数据初始化完成")
	return nil
}