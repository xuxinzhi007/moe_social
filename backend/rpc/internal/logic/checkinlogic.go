package logic

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckInLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCheckInLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckInLogic {
	return &CheckInLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 签到等级相关服务
func (l *CheckInLogic) CheckIn(in *super.CheckInReq) (*super.CheckInResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	// 开启数据库事务
	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 1. 检查用户是否存在
	var user model.User
	if err := tx.Where("id = ?", userID).First(&user).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("用户不存在")
	}

	// 2. 检查今日是否已签到
	today := time.Now().Format("2006-01-02")
	var todayCheckIn model.UserCheckIn
	if err := tx.Where("user_id = ? AND DATE(check_in_date) = ?", userID, today).
		First(&todayCheckIn).Error; err == nil {
		tx.Rollback()
		return nil, fmt.Errorf("今日已签到")
	}

	// 3. 获取最近一次签到记录计算连续天数
	var lastCheckIn model.UserCheckIn
	consecutiveDays := 1
	if err := tx.Where("user_id = ?", userID).Order("check_in_date DESC").
		First(&lastCheckIn).Error; err == nil {
		yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
		lastCheckInDate := lastCheckIn.CheckInDate.Format("2006-01-02")

		if lastCheckInDate == yesterday {
			consecutiveDays = lastCheckIn.ConsecutiveDays + 1
		}
	}

	// 4. 计算经验奖励
	baseExp := 10 // 基础签到经验

	// 获取连续签到额外奖励
	var reward model.CheckInReward
	extraExp := 0
	if err := tx.Where("consecutive_days <= ?", consecutiveDays).
		Order("consecutive_days DESC").First(&reward).Error; err == nil {
		extraExp = reward.ExpReward
	}

	totalExp := baseExp + extraExp

	// 5. VIP用户经验加成
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
		totalExp = int(float64(totalExp) * 1.5) // VIP用户1.5倍经验
	}

	// 6. 获取/创建用户等级记录
	var userLevel model.UserLevel
	if err := tx.Where("user_id = ?", userID).First(&userLevel).Error; err != nil {
		// 创建新的等级记录
		userLevel = model.UserLevel{
			UserID:     uint(userID),
			Level:      1,
			Experience: 0,
			TotalExp:   0,
		}
		if err := tx.Create(&userLevel).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("创建用户等级失败: %v", err)
		}
	}

	oldLevel := userLevel.Level

	// 7. 更新经验值
	userLevel.Experience += totalExp
	userLevel.TotalExp += totalExp

	// 8. 计算新等级
	newLevel := l.calculateLevel(userLevel.TotalExp)
	userLevel.Level = newLevel

	if err := tx.Save(&userLevel).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("更新用户等级失败: %v", err)
	}

	// 9. 记录签到记录
	checkInRecord := model.UserCheckIn{
		UserID:          uint(userID),
		CheckInDate:     time.Now(),
		ConsecutiveDays: consecutiveDays,
		ExpReward:       totalExp,
		IsSpecialReward: extraExp > 0,
	}

	if extraExp > 0 {
		checkInRecord.SpecialRewardDesc = fmt.Sprintf("连续签到%d天额外奖励", consecutiveDays)
	}

	if err := tx.Create(&checkInRecord).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建签到记录失败: %v", err)
	}

	// 10. 记录经验日志
	expLog := model.ExpLog{
		UserID:      uint(userID),
		ExpChange:   totalExp,
		Source:      "check_in",
		SourceID:    fmt.Sprintf("%d", checkInRecord.ID),
		Description: fmt.Sprintf("每日签到获得%d经验", totalExp),
	}

	if err := tx.Create(&expLog).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("创建经验日志失败: %v", err)
	}

	// 11. 提交事务
	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("提交事务失败: %v", err)
	}

	// 12. 返回结果
	specialReward := ""
	if extraExp > 0 {
		specialReward = fmt.Sprintf("连续签到%d天获得额外%d经验", consecutiveDays, extraExp)
	}

	return &super.CheckInResp{
		ExpGained:       int32(totalExp),
		NewLevel:        int32(newLevel),
		ConsecutiveDays: int32(consecutiveDays),
		LevelUp:         newLevel > oldLevel,
		SpecialReward:   specialReward,
	}, nil
}

// calculateLevel 根据总经验计算等级
func (l *CheckInLogic) calculateLevel(totalExp int) int {
	var configs []model.LevelConfig
	if err := l.svcCtx.DB.Order("level ASC").Find(&configs).Error; err != nil {
		// 如果没有配置，使用默认等级计算
		return l.defaultCalculateLevel(totalExp)
	}

	for _, config := range configs {
		if totalExp < config.MaxExp {
			return config.Level
		}
	}

	// 如果超过最高等级，返回最高等级
	if len(configs) > 0 {
		return configs[len(configs)-1].Level
	}

	return 1
}

// defaultCalculateLevel 默认等级计算（没有配置时使用）
func (l *CheckInLogic) defaultCalculateLevel(totalExp int) int {
	if totalExp < 100 {
		return 1
	} else if totalExp < 500 {
		return 2
	} else if totalExp < 2000 {
		return 3
	} else if totalExp < 5000 {
		return 4
	}
	return 5
}