package checkinbiz

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	checkinv1 "backend/api/checkin/v1"
	"backend/model"

	"gorm.io/gorm"
)

// GetUserLevel 用户等级信息。
func GetUserLevel(ctx context.Context, store CheckInStore, userIDRaw string) (*checkinv1.UserLevelInfo, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDRaw), 10, 32)
	if err != nil || userID == 0 {
		return nil, ErrInvalidUserID
	}

	userLevel, ok, err := store.GetUserLevel(ctx, uint(userID))
	if err != nil {
		return nil, err
	}
	if !ok {
		userLevel = model.UserLevel{UserID: uint(userID), Level: 1}
		if err := store.CreateUserLevel(ctx, &userLevel); err != nil {
			return nil, err
		}
	}

	levelConfig, ok, err := store.GetLevelConfig(ctx, userLevel.Level)
	if err != nil {
		return nil, err
	}
	if !ok {
		levelConfig = model.LevelConfig{
			Level:    userLevel.Level,
			Title:    defaultLevelTitle(userLevel.Level),
			BadgeUrl: fmt.Sprintf("/badges/level%d.png", userLevel.Level),
		}
	}

	nextLevelExp := nextLevelMinExp(ctx, store, userLevel.Level)
	currentMin := currentLevelMinExp(ctx, store, userLevel.Level)
	var progress float64
	if nextLevelExp > 0 {
		progress = float64(userLevel.TotalExp-currentMin) / float64(nextLevelExp-currentMin) * 100
		if progress > 100 {
			progress = 100
		}
	}

	return &checkinv1.UserLevelInfo{
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

func nextLevelMinExp(ctx context.Context, store CheckInStore, currentLevel int) int {
	if cfg, ok, err := store.GetLevelConfig(ctx, currentLevel+1); err == nil && ok {
		return cfg.MinExp
	}
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

func currentLevelMinExp(ctx context.Context, store CheckInStore, currentLevel int) int {
	if cfg, ok, err := store.GetLevelConfig(ctx, currentLevel); err == nil && ok {
		return cfg.MinExp
	}
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
