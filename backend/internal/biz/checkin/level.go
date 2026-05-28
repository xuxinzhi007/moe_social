package checkinbiz

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// GetUserLevel 用户等级信息。
func GetUserLevel(ctx context.Context, db *gorm.DB, userIDRaw string) (*moe.UserLevelInfo, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, ErrInvalidUserID
	}

	var userLevel model.UserLevel
	if err := db.WithContext(ctx).Where("user_id = ?", userID).First(&userLevel).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			userLevel = model.UserLevel{UserID: uint(userID), Level: 1}
			if err := db.WithContext(ctx).Create(&userLevel).Error; err != nil {
				return nil, err
			}
		} else {
			return nil, err
		}
	}

	var levelConfig model.LevelConfig
	if err := db.WithContext(ctx).Where("level = ?", userLevel.Level).First(&levelConfig).Error; err != nil {
		levelConfig = model.LevelConfig{
			Level:    userLevel.Level,
			Title:    defaultLevelTitle(userLevel.Level),
			BadgeUrl: fmt.Sprintf("/badges/level%d.png", userLevel.Level),
		}
	}

	nextLevelExp := nextLevelMinExp(db.WithContext(ctx), userLevel.Level)
	currentMin := currentLevelMinExp(db.WithContext(ctx), userLevel.Level)
	var progress float64
	if nextLevelExp > 0 {
		progress = float64(userLevel.TotalExp-currentMin) / float64(nextLevelExp-currentMin) * 100
		if progress > 100 {
			progress = 100
		}
	}

	return &moe.UserLevelInfo{
		Level: int32(userLevel.Level), Experience: int32(userLevel.Experience),
		TotalExp: int32(userLevel.TotalExp), NextLevelExp: int32(nextLevelExp),
		LevelTitle: levelConfig.Title, BadgeUrl: levelConfig.BadgeUrl, Progress: progress,
	}, nil
}

func defaultLevelTitle(level int) string {
	titles := map[int]string{1: "萌新菜鸟", 2: "活跃新手", 3: "社区中坚", 4: "资深达人", 5: "社区大师"}
	if title, ok := titles[level]; ok {
		return title
	}
	return fmt.Sprintf("等级%d", level)
}

func nextLevelMinExp(db *gorm.DB, currentLevel int) int {
	var nextConfig model.LevelConfig
	if err := db.Where("level = ?", currentLevel+1).First(&nextConfig).Error; err != nil {
		switch currentLevel {
		case 1:
			return 100
		case 2:
			return 500
		case 3:
			return 2000
		case 4:
			return 5000
		default:
			return 999999
		}
	}
	return nextConfig.MinExp
}

func currentLevelMinExp(db *gorm.DB, currentLevel int) int {
	var config model.LevelConfig
	if err := db.Where("level = ?", currentLevel).First(&config).Error; err != nil {
		switch currentLevel {
		case 1:
			return 0
		case 2:
			return 100
		case 3:
			return 500
		case 4:
			return 2000
		case 5:
			return 5000
		default:
			return 0
		}
	}
	return config.MinExp
}
