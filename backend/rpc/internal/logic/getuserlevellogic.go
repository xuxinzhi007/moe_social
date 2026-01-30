package logic

import (
	"context"
	"fmt"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserLevelLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserLevelLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserLevelLogic {
	return &GetUserLevelLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserLevelLogic) GetUserLevel(in *super.GetUserLevelReq) (*super.GetUserLevelResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	// 1. 获取用户等级记录
	var userLevel model.UserLevel
	if err := l.svcCtx.DB.Where("user_id = ?", userID).First(&userLevel).Error; err != nil {
		// 用户没有等级记录，创建默认等级记录
		userLevel = model.UserLevel{
			UserID:     uint(userID),
			Level:      1,
			Experience: 0,
			TotalExp:   0,
		}
		if err := l.svcCtx.DB.Create(&userLevel).Error; err != nil {
			return nil, fmt.Errorf("创建用户等级失败: %v", err)
		}
	}

	// 2. 获取等级配置信息
	var levelConfig model.LevelConfig
	if err := l.svcCtx.DB.Where("level = ?", userLevel.Level).First(&levelConfig).Error; err != nil {
		// 没有配置，使用默认值
		levelConfig = model.LevelConfig{
			Level:    userLevel.Level,
			Title:    l.getDefaultLevelTitle(userLevel.Level),
			BadgeUrl: fmt.Sprintf("/badges/level%d.png", userLevel.Level),
		}
	}

	// 3. 计算下一等级所需经验
	nextLevelExp := l.getNextLevelExp(userLevel.Level)

	// 4. 计算进度百分比
	var progress float64
	if nextLevelExp > 0 {
		currentLevelMinExp := l.getCurrentLevelMinExp(userLevel.Level)
		progress = float64(userLevel.TotalExp-currentLevelMinExp) / float64(nextLevelExp-currentLevelMinExp) * 100
		if progress > 100 {
			progress = 100
		}
	}

	return &super.GetUserLevelResp{
		LevelInfo: &super.UserLevelInfo{
			Level:        int32(userLevel.Level),
			Experience:   int32(userLevel.Experience),
			TotalExp:     int32(userLevel.TotalExp),
			NextLevelExp: int32(nextLevelExp),
			LevelTitle:   levelConfig.Title,
			BadgeUrl:     levelConfig.BadgeUrl,
			Progress:     progress,
		},
	}, nil
}

// getDefaultLevelTitle 获取默认等级标题
func (l *GetUserLevelLogic) getDefaultLevelTitle(level int) string {
	titles := map[int]string{
		1: "萌新菜鸟",
		2: "活跃新手",
		3: "社区中坚",
		4: "资深达人",
		5: "社区大师",
	}
	if title, ok := titles[level]; ok {
		return title
	}
	return fmt.Sprintf("等级%d", level)
}

// getNextLevelExp 获取下一等级所需经验
func (l *GetUserLevelLogic) getNextLevelExp(currentLevel int) int {
	var nextConfig model.LevelConfig
	if err := l.svcCtx.DB.Where("level = ?", currentLevel+1).First(&nextConfig).Error; err != nil {
		// 使用默认配置
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
			return 999999 // 最高等级
		}
	}
	return nextConfig.MinExp
}

// getCurrentLevelMinExp 获取当前等级的最低经验
func (l *GetUserLevelLogic) getCurrentLevelMinExp(currentLevel int) int {
	var config model.LevelConfig
	if err := l.svcCtx.DB.Where("level = ?", currentLevel).First(&config).Error; err != nil {
		// 使用默认配置
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